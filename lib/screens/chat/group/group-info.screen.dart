import 'dart:async';
import 'package:amigo/db/repositories/contacts.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/providers/chat.provider.dart';
import 'package:amigo/providers/message.provider.dart';
import 'package:amigo/services/contact.service.dart';
import 'package:amigo/services/user-status.service.dart';
import 'package:amigo/utils/animations.utils.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../models/group.model.dart';
import '../../../models/user.model.dart';
import '../../../config/app-colors.config.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../ui/snackbar.dart';

class GroupInfoPage extends ConsumerStatefulWidget {
  final GroupModel group;

  const GroupInfoPage({super.key, required this.group});

  @override
  ConsumerState<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends ConsumerState<GroupInfoPage>
    with SingleTickerProviderStateMixin {
  final ContactService _contactService = ContactService();

  final ConversationRepository _conversationRepository =
      ConversationRepository();
  final ConversationMemberRepository _conversationMemberRepository =
      ConversationMemberRepository();
  final UserRepository _userRepository = UserRepository();

  final UserUtils _userUtils = UserUtils();
  final apiService = ApiService();
  final UserStatusService _userStatusService = UserStatusService();

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
      final nameMatch = user.displayName.toLowerCase().contains(query);
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

        // Enrich member data with display names from users table first
        await _enrichMembersWithDisplayNames(groupInfoMap);

        // Add creator information if available (after enrichment)
        if (conv != null) {
          groupInfoMap['createrId'] = conv.createrId;
          // Find creator name from enriched members map
          String? creatorName;
          if (groupInfoMap['members'] != null) {
            final List<dynamic> members = groupInfoMap['members'];
            try {
              final creatorMember = members.firstWhere(
                (member) => member['userId'] == conv.createrId,
              );
              // After enrichment, userName will have the displayName
              creatorName = creatorMember['userName'] ?? creatorMember['name'];
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
            creatorName = creatorUser?.displayName ?? 'Unknown';
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
  }

  /// Enrich member data with display names from users table
  Future<void> _enrichMembersWithDisplayNames(
    Map<String, dynamic> groupInfoMap,
  ) async {
    try {
      if (groupInfoMap['members'] == null) return;

      final List<dynamic> members = groupInfoMap['members'];
      for (var member in members) {
        if (member is Map<String, dynamic> && member['userId'] != null) {
          final user = await _userRepository.getUserById(member['userId']);
          if (user != null) {
            // Update the member's userName with the displayName from users table
            member['userName'] = user.displayName;
          }
        }
      }
    } catch (e) {
      debugPrint('Error enriching members with display names: $e');
    }
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
      // final localContacts = await _contactsRepository.getAllContacts();
      // if (localContacts.isNotEmpty) {
      //   setState(() {
      //     _availableUsers = localContacts;
      //   });
      // } else {
      final contacts = await _contactService.fetchContacts();
      if (contacts.isEmpty) {
        return;
      }
      final contactsData = contacts
          .map((contact) => contact.phoneNumber)
          .toList();
      final response = (await apiService.user.getAvailableUsers(
        contactsData,
      )).toMap();
      if (response['success'] == true && response['data'] != null) {
        final usersData = response['data'] as List<dynamic>;
        final users = usersData
            .map((userJson) => UserModel.fromJson(userJson))
            .toList();
        // print("Available users from the server $users");
        // Enrich users with display names from local database
        final enrichedUsers = await _userUtils.enrichUsersWithDisplayNames(
          users,
        );

        setState(() {
          _availableUsers = enrichedUsers;
        });
        // }
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

  bool _isCurrentUserCreator() {
    if (_currentUserDetails?.id == null) return false;
    final creatorId = _groupInfo?['createrId'] ?? _groupInfo?['created_by'];
    return _currentUserDetails?.id == creatorId;
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation1, curve: Curves.easeOut),
            ),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Group Name',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter a new name for this group',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 50,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Group name',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        counterStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: themeColor.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final newTitle = controller.text.trim();
                    if (newTitle.isNotEmpty &&
                        newTitle != _groupInfo?['title']) {
                      Navigator.pop(context);
                      await _updateGroupTitle(newTitle);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: themeColor.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateGroupTitle(String newTitle) async {
    try {
      setState(() {
        _isUpdatingTitle = true;
      });

      final response = (await apiService.group.updateGroupTitle(
        title: newTitle,
        conversationId: widget.group.conversationId,
      )).toMap();

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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedUserIds.isEmpty
                                ? '${_availableUsers.length} contacts available'
                                : '${_selectedUserIds.length} selected',
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedUserIds.isEmpty
                                  ? Colors.grey.shade500
                                  : themeColor.primary,
                              fontWeight: _selectedUserIds.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isRefreshingContacts
                          ? null
                          : () async {
                              await _refreshContacts();
                              (context as Element).markNeedsBuild();
                            },
                      icon: _isRefreshingContacts
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey.shade400,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                      tooltip: 'Refresh contacts',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setDialogState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Colors.grey.shade400,
                              size: 18,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                _searchQuery = '';
                                searchController.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              // Quick actions row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    if (_filteredUsers.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            final allSelected = _filteredUsers.every(
                              (u) => _selectedUserIds.contains(u.id),
                            );
                            if (allSelected) {
                              for (var u in _filteredUsers) {
                                _selectedUserIds.remove(u.id);
                              }
                            } else {
                              _selectedUserIds.addAll(
                                _filteredUsers.map((u) => u.id),
                              );
                            }
                          });
                        },
                        child: Text(
                          _filteredUsers.every(
                                (u) => _selectedUserIds.contains(u.id),
                              )
                              ? 'Deselect all'
                              : 'Select all',
                          style: TextStyle(
                            fontSize: 13,
                            color: themeColor.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (_filteredUsers.any(
                      (u) => u.role?.toLowerCase() == 'staff',
                    )) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            final staffIds = _filteredUsers
                                .where((u) => u.role?.toLowerCase() == 'staff')
                                .map((u) => u.id);
                            _selectedUserIds.addAll(staffIds);
                          });
                        },
                        child: Text(
                          'Staff only',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _searchQuery.isEmpty
                          ? '${_filteredUsers.length} contacts'
                          : '${_filteredUsers.length} results',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Users List
              Expanded(
                child: _filteredUsers.isEmpty && _searchQuery.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filteredUsers.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 68,
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final isSelected = _selectedUserIds.contains(user.id);

                          return StaggeredSlideFadeItem(
                            index: index,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: isSelected
                                            ? themeColor.primaryLight
                                                  .withOpacity(0.3)
                                            : Colors.grey.shade100,
                                        backgroundImage: user.profilePic != null
                                            ? NetworkImage(user.profilePic!)
                                            : null,
                                        child: user.profilePic == null
                                            ? Text(
                                                user.displayName.isNotEmpty
                                                    ? user.displayName[0]
                                                          .toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? themeColor.primary
                                                      : Colors.grey.shade500,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    user.displayName,
                                                    style: TextStyle(
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                      fontSize: 15,
                                                      color: Colors.black87,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (user.role?.toLowerCase() ==
                                                    'staff')
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.blue.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'Staff',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .blue
                                                            .shade600,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              user.phone,
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? themeColor.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? themeColor.primary
                                                : Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              )
                                            : null,
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

              // Bottom action
              if (_selectedUserIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addMembers(_selectedUserIds.toList());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add ${_selectedUserIds.length} Member${_selectedUserIds.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
      final id = TaskSnack.show(message: 'Adding Members...');

      // Add all members at once
      final response = (await apiService.group.addMember(
        conversationId: widget.group.conversationId,
        userIds: userIds,
      )).toMap();

      // Show result message
      if (response['success'] == true) {
        TaskSnack.resolve(id: id, isSuccess: true, message: 'Members Added');

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
        TaskSnack.resolve(
          id: id,
          isSuccess: false,
          message: response['message'] ?? 'Failed to add members',
        );
      }

      // Refresh group info
      await _loadGroupInfoFromLocal();
    } catch (e) {
      TaskSnack.dismiss();
      // Close loading dialog if still open
      Snack.error("Error adding members: $e");
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
        final id = TaskSnack.show(message: 'Promoting $userName to admin...');

        final response = (await apiService.group.promoteToAdmin(
          conversationId: widget.group.conversationId,
          userId: userId,
        )).toMap();

        if (response['success'] == true) {
          TaskSnack.resolve(
            id: id,
            isSuccess: true,
            message: '$userName is now an admin',
          );

          await _conversationMemberRepository.updateMemberRole(
            widget.group.conversationId,
            userId,
            'admin',
          );
          await _loadGroupInfoFromLocal(); // Refresh group info
        } else {
          TaskSnack.resolve(
            id: id,
            isSuccess: false,
            message: response['message'] ?? 'Failed to promote member',
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        TaskSnack.dismiss();
        Snack.error("Error promoting member: $e");
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
        final id = TaskSnack.show(message: 'Demoting $userName to member');

        final response = (await apiService.group.demoteToMember(
          conversationId: widget.group.conversationId,
          userId: userId,
        )).toMap();

        if (response['success'] == true) {
          TaskSnack.resolve(
            id: id,
            isSuccess: true,
            message: '$userName has been demoted to member',
          );
          await _conversationMemberRepository.updateMemberRole(
            widget.group.conversationId,
            userId,
            'member',
          );
          await _loadGroupInfoFromLocal(); // Refresh group info
        } else {
          TaskSnack.resolve(
            id: id,
            isSuccess: false,
            message: response['message'] ?? 'Failed to demote member',
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        TaskSnack.dismiss();
        Snack.error("Error demoting member: $e");
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
                              Icons.person_remove_rounded,
                              size: 48,
                              color: Colors.red.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Remove Member',
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
                                const TextSpan(text: 'Remove '),
                                TextSpan(
                                  text: userName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const TextSpan(text: ' from this group?'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                backgroundColor: Colors.red.shade600,
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
                                  Icon(Icons.person_remove_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Remove',
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
      try {
        final response = (await apiService.group.removeMember(
          conversationId: widget.group.conversationId,
          userId: userId,
        )).toMap();

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

  Future<void> _showRemoveAllMembersDialog() async {
    if (!_isCurrentUserCreator()) {
      _showSnackBar(
        'Only the group creator can remove all members',
        isError: true,
      );
      return;
    }

    if (_groupInfo?['members'] == null) return;
    final List<dynamic> members = _groupInfo!['members'];
    final creatorId = _groupInfo?['createrId'] ?? _groupInfo?['created_by'];

    // Filter out the creator from the list
    final membersToRemove = members
        .where((member) => member['userId'] != creatorId)
        .toList();

    if (membersToRemove.isEmpty) {
      _showSnackBar('No members to remove', isError: true);
      return;
    }

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
                              Icons.delete_sweep,
                              size: 48,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Remove All Members',
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
                                  text: 'Are you sure you want to remove all ',
                                ),
                                TextSpan(
                                  text:
                                      '${membersToRemove.length} member${membersToRemove.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const TextSpan(text: ' from this group?'),
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
                                    'This will remove all members except you (the creator). This action cannot be undone.',
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_sweep, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Remove All',
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
      await _removeAllMembers(membersToRemove);
    }
  }

  Future<void> _removeAllMembers(List<dynamic> membersToRemove) async {
    if (!_isCurrentUserCreator()) {
      _showSnackBar(
        'Only the group creator can remove all members',
        isError: true,
      );
      return;
    }

    try {
      final loadingId = TaskSnack.show(message: 'Removing all members...');

      // Remove all members one by one
      int successCount = 0;
      int failCount = 0;

      for (var member in membersToRemove) {
        final userId = member['userId'];
        try {
          final response = (await apiService.group.removeMember(
            conversationId: widget.group.conversationId,
            userId: userId,
          )).toMap();

          if (response['success'] == true) {
            successCount++;
            await _conversationMemberRepository
                .deleteMemberByConversationAndUserId(
                  widget.group.conversationId,
                  userId,
                );
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          debugPrint('Error removing member $userId: $e');
        }
      }

      if (successCount > 0) {
        TaskSnack.resolve(
          id: loadingId,
          isSuccess: true,
          message: failCount > 0
              ? '$successCount member${successCount > 1 ? 's' : ''} removed. $failCount failed.'
              : 'All members removed successfully',
        );
        await _loadGroupInfoFromLocal(); // Refresh group info
      } else {
        TaskSnack.resolve(
          id: loadingId,
          isSuccess: false,
          message: 'Failed to remove members',
        );
      }
    } catch (e) {
      TaskSnack.dismiss();
      _showSnackBar('Error removing all members: $e', isError: true);
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
      final loadingId = TaskSnack.show(message: 'Deleting group');

      final response = (await apiService.group.deleteGroup(
        widget.group.conversationId,
      )).toMap();

      if (response['success'] == true) {
        // Delete from local database
        await _conversationRepository.deleteConversation(
          widget.group.conversationId,
        );

        // Update state to remove the group
        ref
            .read(chatProvider.notifier)
            .removeGroupFromState(widget.group.conversationId);

        TaskSnack.resolve(
          id: loadingId,
          isSuccess: true,
          message: 'Group deleted successfully',
        );

        // Navigate back with deletion result
        // This will be handled by InnerGroupChatPage
        Navigator.pop(context, {'action': 'deleted'});
      } else {
        TaskSnack.resolve(
          id: loadingId,
          isSuccess: false,
          message: response['message'] ?? 'Failed to delete group',
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      TaskSnack.dismiss();
      Snack.error("Error deleting group: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      Snack.error(message);
    } else {
      Snack.success(message);
    }
  }

  // ─── UI Helpers ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader(ColorTheme themeColor) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor.primary, themeColor.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPadding + kToolbarHeight + 8, 24, 44),
      child: Column(
        children: [
          // Avatar with glow shadow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _buildGroupAvatar(
              _groupInfo?['title'] ?? 'Group',
              radius: 52,
            ),
          ),
          const SizedBox(height: 20),
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _capitalizeFirstLetter(_groupInfo?['title'] ?? 'Group'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_isCurrentUserAdmin()) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isUpdatingTitle ? null : _showEditTitleDialog,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: _isUpdatingTitle
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 15,
                          ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Member count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${_groupInfo?['members']?.length ?? 0} members',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Creator info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: Colors.white.withOpacity(0.65),
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                'Created by ${_groupInfo?['createrName'] ?? 'Unknown'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorTheme themeColor) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: topPadding + kToolbarHeight + 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeColor.primary, themeColor.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.7),
              ),
              strokeWidth: 2.5,
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            children: List.generate(5, (i) => _AnimatedSkeletonTile(index: i)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ColorTheme themeColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadGroupInfoFromLocal,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(ColorTheme themeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Members',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _memberSearchQuery.isEmpty
                            ? '${_groupInfo?['members']?.length ?? 0} participants'
                            : '${_filteredMembers.length} result${_filteredMembers.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action chips
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCurrentUserAdmin())
                      _buildActionChip(
                        icon: Icons.person_add_outlined,
                        label: 'Add',
                        color: themeColor.primary,
                        onTap: _showAddMemberDialog,
                      ),
                    if (_isCurrentUserCreator() &&
                        _groupInfo?['members'] != null)
                      Builder(
                        builder: (context) {
                          final List<dynamic> members = _groupInfo!['members'];
                          final creatorId =
                              _groupInfo?['createrId'] ??
                              _groupInfo?['created_by'];
                          final membersToRemove = members
                              .where((m) => m['userId'] != creatorId)
                              .toList();
                          if (membersToRemove.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildActionChip(
                              icon: Icons.delete_sweep_outlined,
                              label: 'Clear',
                              color: Colors.red.shade600,
                              onTap: _showRemoveAllMembersDialog,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _memberSearchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search members',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                suffixIcon: _memberSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade400,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _memberSearchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Member list
          if (_groupInfo?['members'] != null)
            if (_filteredMembers.isEmpty && _memberSearchQuery.isNotEmpty)
              _buildEmptySearch()
            else
              ...(_filteredMembers.asMap().entries.map((entry) {
                final index = entry.key;
                final member = entry.value as Map<String, dynamic>;
                return _AnimatedMemberTile(
                  key: ValueKey(member['userId']),
                  index: index,
                  child: _buildMemberTile(member, themeColor),
                );
              }).toList()),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No members found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, ColorTheme themeColor) {
    final isAdmin = member['role'] == 'admin';
    final isCreator = _isGroupCreator(member['userId']);
    final isCurrentUser = member['userId'] == _currentUserDetails?.id;
    final userId = member['userId'];
    final isOnline = userId is int
        ? _userStatusService.isUserOnline(userId)
        : false;
    final userName =
        (member['userName'] ?? member['name'] ?? 'Unknown') as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? themeColor.primaryLight.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(
                color: themeColor.primaryLight.withOpacity(0.4),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar with online indicator dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isCreator
                      ? Colors.purple.shade100
                      : isAdmin
                      ? Colors.amber.shade100
                      : themeColor.primaryLight.withOpacity(0.3),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isCreator
                          ? Colors.purple.shade700
                          : isAdmin
                          ? Colors.amber.shade700
                          : themeColor.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.45),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name & badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isCurrentUser
                                ? themeColor.primary
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        _buildBadge('You', themeColor.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isCreator) ...[
                        _buildBadge(
                          'Creator',
                          Colors.purple.shade500,
                          icon: Icons.star_rounded,
                        ),
                        const SizedBox(width: 5),
                      ],
                      _buildBadge(
                        isAdmin ? 'Admin' : 'Member',
                        isAdmin ? Colors.amber.shade700 : Colors.grey.shade500,
                        outlined: !isAdmin,
                      ),
                      if (isOnline) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Admin actions via popup menu
            if (_isCurrentUserAdmin() && !isCurrentUser)
              _buildMemberActionsMenu(member, isAdmin, isCreator, themeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    String text,
    Color color, {
    IconData? icon,
    bool outlined = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 6 : 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(6),
        border: outlined ? Border.all(color: color.withOpacity(0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberActionsMenu(
    Map<String, dynamic> member,
    bool isAdmin,
    bool isCreator,
    ColorTheme themeColor,
  ) {
    final userName =
        (member['userName'] ?? member['name'] ?? 'Unknown') as String;
    final userId = member['userId'] as int;

    return PopupMenuButton<String>(
      color: Colors.white,
      icon: Icon(
        Icons.more_vert_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.15),
      offset: const Offset(0, 8),
      onSelected: (value) {
        switch (value) {
          case 'promote':
            _promoteToAdmin(userId, userName);
          case 'demote':
            _demoteToMember(userId, userName);
          case 'remove':
            _removeMember(userId, userName);
        }
      },
      itemBuilder: (context) => [
        if (!isAdmin)
          PopupMenuItem(
            value: 'promote',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.amber.shade600,
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Text('Make Admin', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        if (isAdmin && !isCreator)
          PopupMenuItem(
            value: 'demote',
            child: Row(
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  color: Colors.orange.shade600,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Remove Admin',
                  style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.person_remove_outlined,
                color: Colors.red.shade600,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Remove',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(ColorTheme themeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.shade100, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_outlined,
                color: Colors.red.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Group',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Permanently deletes this group and all messages',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _showDeleteGroupDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    // Rebuild whenever any user's online status changes
    ref.watch(userStatusStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Group Info',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState(themeColor)
          : _errorMessage != null
          ? _buildErrorState(themeColor)
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Gradient hero header
                    _buildHeroHeader(themeColor),

                    // Content card slides up from below the header
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Drag handle visual indicator
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            _buildMembersSection(themeColor),
                            if (_isCurrentUserAdmin())
                              _buildDangerZone(themeColor),
                            SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Staggered member tile entrance animation ──────────────────────────────

class _AnimatedMemberTile extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedMemberTile({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedMemberTile> createState() => _AnimatedMemberTileState();
}

class _AnimatedMemberTileState extends State<_AnimatedMemberTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 55), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Animated skeleton loading tile ───────────────────────────────────────

class _AnimatedSkeletonTile extends StatefulWidget {
  final int index;
  const _AnimatedSkeletonTile({required this.index});

  @override
  State<_AnimatedSkeletonTile> createState() => _AnimatedSkeletonTileState();
}

class _AnimatedSkeletonTileState extends State<_AnimatedSkeletonTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Opacity(
        opacity: _anim.value,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 68,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
