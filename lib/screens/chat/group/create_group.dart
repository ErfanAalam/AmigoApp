import 'package:amigo/db/repositories/conversation_member.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/group_model.dart';
import 'package:amigo/screens/chat/group/messaging.dart';
import 'package:amigo/types/socket.type.dart';
import 'package:amigo/utils/route_transitions.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../api/groups.services.dart';
import '../../../api/user.service.dart';
import '../../../services/contact_service.dart';
import '../../../services/socket/websocket_service.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/theme_color_provider.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final GroupsService _groupsService = GroupsService();
  final UserService _userService = UserService();
  final ContactService _contactService = ContactService();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final WebSocketService _websocketService = WebSocketService();

  final ConversationRepository _conversationRepo = ConversationRepository();
  final ConversationMemberRepository _conversationMemberRepo =
      ConversationMemberRepository();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  Set<int> _selectedUserIds = {};
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
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.name.toLowerCase().contains(query) ||
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
      // First load contacts to get phone numbers
      final contacts = await _contactService.fetchContacts();
      final contactPhones = contacts
          .map((contact) => contact.phoneNumber)
          .toList();

      // Load available users from the same API used in contacts
      final response = await _userService.getAvailableUsers(contactPhones);

      if (response['success'] && response['data'] != null) {
        final List<dynamic> usersData = response['data'];
        final users = usersData
            .map((userData) => UserModel.fromJson(userData))
            .toList();

        setState(() {
          _allUsers = users;
          _filteredUsers = List.from(users);
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
        final themeColor = ref.watch(themeColorProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'NO Contact found please add some contacts to your phone: ${e.toString()}',
            ),
            backgroundColor: themeColor.primary,
          ),
        );
      }
    }
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final response = await _groupsService.createGroup(
        groupName,
        _selectedUserIds.toList(),
      );

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Group "$groupName" created successfully!'),
              backgroundColor: Colors.teal,
            ),
          );

          final newGroupConversation = GroupModel(
            conversationId: response['data']['id'],
            title: groupName,
            joinedAt: DateTime.now().toIso8601String(),
          );

          final newGroup = ConversationModel(
            id: response['data']['id'],
            type: 'group',
            unreadCount: 0,
            title: groupName,
            pinnedMessageId: null,
            createrId: (await UserUtils().getUserDetails())?.id ?? 0,
            createdAt: DateTime.now().toIso8601String(),
          );

          await _conversationRepo.insertConversations([newGroup]);

          for (var userId in _selectedUserIds) {
            final receiverMember = ConversationMemberModel(
              conversationId: response['data']['id'],
              userId: userId,
              role: 'member',
              joinedAt: DateTime.now().toIso8601String(),
            );

            // Store conversation members in SQLite
            await _conversationMemberRepo.insertConversationMembers([
              receiverMember,
            ]);
          }
          // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
          // Send WebSocket messages in background (non-blocking, non-critical)
          final joinConvPayload = JoinLeavePayload(
            convId: response['data']['id'],
            convType: ChatType.group,
            userId: (await UserUtils().getUserDetails())?.id ?? 0,
            userName: (await UserUtils().getUserDetails())?.name ?? '',
          ).toJson();

          final wsmsg = WSMessage(
            type: WSMessageType.conversationJoin,
            payload: joinConvPayload,
            wsTimestamp: DateTime.now(),
          ).toJson();

          await _websocketService.sendMessage(wsmsg);
          // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

          // Add the new group to the chat provider state
          await ref
              .read(chatProvider.notifier)
              .addNewGroup(newGroupConversation);

          await Navigator.pushAndRemoveUntil(
            context,
            SlideRightRoute(
              page: InnerGroupChatPage(group: newGroupConversation),
            ),
            (route) => route.isFirst, // Keep only the initial route (home)
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to create group');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error creating group please try again: ${e.toString()}',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Group',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _isCreating ? null : _createGroup,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'CREATE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Group Name Input
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Group name',
                prefixIcon: Icon(Icons.group, color: themeColor.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeColor.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          // Selected Members Count
          if (_selectedUserIds.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: themeColor.primaryLight,
              child: Text(
                '${_selectedUserIds.length} member${_selectedUserIds.length > 1 ? 's' : ''} selected',
                style: TextStyle(
                  color: themeColor.primaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredUsers.isEmpty
                ? _buildEmptyState()
                : _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final themeColor = ref.watch(themeColorProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(themeColor.primaryDark),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading users...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
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
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final isSelected = _selectedUserIds.contains(user.id);

        return UserListItem(
          user: user,
          isSelected: isSelected,
          onTap: () => _toggleUserSelection(user.id),
        );
      },
    );
  }
}

class UserListItem extends ConsumerWidget {
  final UserModel user;
  final bool isSelected;
  final VoidCallback onTap;

  const UserListItem({
    super.key,
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

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
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? themeColor.primaryLight : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: themeColor.primaryLight,
              backgroundImage: user.profilePic != null
                  ? NetworkImage(user.profilePic!)
                  : null,
              child: user.profilePic == null
                  ? Text(
                      _getInitials(user.name),
                      style: TextStyle(
                        color: themeColor.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            if (isSelected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: themeColor.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          user.phone,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: themeColor.primary, size: 24)
            : Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey[400],
                size: 24,
              ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
