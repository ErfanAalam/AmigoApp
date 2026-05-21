import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/utils/animations.utils.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../models/group.model.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/contact.service.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../types/socket.types.dart';
import '../../../utils/route-transitions.util.dart';
import '../../../ui/snackbar.dart';
import 'group-messaging.screen.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final apiService = ApiService();
  final ContactService _contactService = ContactService();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TransportManager _transportManager = TransportManager();
  final FocusNode _groupNameFocus = FocusNode();

  final ConversationRepository _conversationRepo = ConversationRepository();
  final ConversationMemberRepository _conversationMemberRepo =
      ConversationMemberRepository();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    _groupNameFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.displayName.toLowerCase().contains(query) ||
              user.phone.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await _contactService.fetchContacts();
      final contactPhones = contacts
          .map((contact) => contact.phoneNumber)
          .toList();

      final response = (await apiService.user.getAvailableUsers(
        contactPhones,
      )).toMap();

      if (response['success'] && response['data'] != null) {
        final List<dynamic> usersData = response['data'];
        final users = usersData
            .map((userData) => UserModel.fromJson(userData))
            .toList();

        final enrichedUsers = await UserUtils().enrichUsersWithDisplayNames(
          users,
        );
        enrichedUsers.sort(
          (a, b) =>
              a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        );

        setState(() {
          _allUsers = enrichedUsers;
          _filteredUsers = List.from(enrichedUsers);
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load users');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Snack.error(
          'NO Contact found please add some contacts to your phone: ${e.toString()}',
        );
      }
    }
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _selectAllUsers() {
    setState(() {
      _selectedUserIds.addAll(_filteredUsers.map((user) => user.id));
    });
  }

  void _deselectAllUsers() {
    setState(() {
      _selectedUserIds.clear();
    });
  }

  bool get _areAllFilteredUsersSelected {
    if (_filteredUsers.isEmpty) return false;
    return _filteredUsers.every((user) => _selectedUserIds.contains(user.id));
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      Snack.warning('Please enter a group name');
      _groupNameFocus.requestFocus();
      return;
    }

    if (_selectedUserIds.isEmpty) {
      Snack.warning('Please select at least one member');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final response = (await apiService.group.createGroup(
        title: groupName,
        memberIds: _selectedUserIds.toList(),
      )).toMap();

      if (response['success']) {
        if (mounted) {
          Snack.success('Group "$groupName" created successfully!');

          final newChatId = response['data']['id'].toString();
          final currentUser = await UserUtils().getUserDetails();
          final newGroupConversation = GroupModel(
            chatId: newChatId,
            title: groupName,
            joinedAt: DateTime.now().toIso8601String(),
          );

          final newGroup = ConversationModel(
            id: newChatId,
            type: 'group',
            unreadCount: 0,
            title: groupName,
            createrId: currentUser?.id ?? '',
            createdAt: DateTime.now().toIso8601String(),
          );

          await _conversationRepo.insertConversations([newGroup]);

          for (var userId in _selectedUserIds) {
            final receiverMember = ConversationMemberModel(
              chatId: newChatId,
              userId: userId,
              role: 'member',
              joinedAt: DateTime.now().toIso8601String(),
            );

            await _conversationMemberRepo.insertConversationMembers([
              receiverMember,
            ]);
          }

          final joinConvPayload = ConvJoinPayload(
            convId: newChatId,
            userId: currentUser?.id ?? '',
            lastReadMsgId: '',
          ).toJson();

          final wsmsg = WSMessage(
            type: WSMessageType.conversationJoin,
            payload: joinConvPayload,
            wsTimestamp: DateTime.now(),
          ).toJson();

          await _transportManager.sendMessage(wsmsg);

          await ref
              .read(chatProvider.notifier)
              .addNewGroup(newGroupConversation);

          await Navigator.pushAndRemoveUntil(
            context,
            SlideRightRoute(
              page: InnerGroupChatPage(group: newGroupConversation),
            ),
            (route) => route.isFirst,
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to create group');
      }
    } catch (e) {
      if (mounted) {
        Snack.error('Error creating group please try again: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  String _getInitials(String name) {
    final words = name
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'New Group',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Group name + search section
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // Group name input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: TextField(
                    controller: _groupNameController,
                    focusNode: _groupNameFocus,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Group name',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade50,
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
                ),

                // Search input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
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
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      if (_filteredUsers.isNotEmpty)
                        GestureDetector(
                          onTap: _areAllFilteredUsersSelected
                              ? _deselectAllUsers
                              : _selectAllUsers,
                          child: Text(
                            _areAllFilteredUsersSelected
                                ? 'Deselect all'
                                : 'Select all',
                            style: TextStyle(
                              fontSize: 13,
                              color: themeColor.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (_selectedUserIds.isNotEmpty)
                        Text(
                          '${_selectedUserIds.length} selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeColor.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          '${_filteredUsers.length} contacts',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                ),

                Divider(height: 1, color: Colors.grey.shade100),
              ],
            ),
          ),

          // Selected members chips
          if (_selectedUserIds.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: _selectedUserIds.map((id) {
                    final user = _allUsers.firstWhere(
                      (u) => u.id == id,
                      orElse: () => _allUsers.first,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: StaggeredScaleFadeTile(
                        index: 0,
                        staggerDelayMs: 0,
                        child: Chip(
                          label: Text(
                            user.displayName,
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => _toggleUserSelection(id),
                          backgroundColor: themeColor.primaryLight.withOpacity(
                            0.15,
                          ),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Users list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: themeColor.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : _filteredUsers.isEmpty
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
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
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
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => _toggleUserSelection(user.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isSelected
                                        ? themeColor.primaryLight.withOpacity(
                                            0.3,
                                          )
                                        : Colors.grey.shade100,
                                    backgroundImage: user.profilePic != null
                                        ? NetworkImage(user.profilePic!)
                                        : null,
                                    child: user.profilePic == null
                                        ? Text(
                                            _getInitials(user.displayName),
                                            style: TextStyle(
                                              color: isSelected
                                                  ? themeColor.primary
                                                  : Colors.grey.shade500,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
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
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (user.role?.toLowerCase() ==
                                                'staff')
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Staff',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade600,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
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
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? themeColor.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
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
        ],
      ),

      // Bottom create button
      bottomNavigationBar: _selectedUserIds.isNotEmpty
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 +
                    (bottomInset > 0
                        ? 0
                        : MediaQuery.of(context).padding.bottom),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: themeColor.primary.withOpacity(
                      0.6,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create Group (${_selectedUserIds.length} member${_selectedUserIds.length > 1 ? 's' : ''})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }
}
