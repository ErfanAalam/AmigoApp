// import 'dart:convert';
import 'package:amigo/db/repositories/contacts.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/chat.api-client.dart';
import '../../api/user.api-client.dart';
import '../../db/repositories/conversation-member.repo.dart';
import '../../models/contact.model.dart';
import '../../models/user.model.dart';
import '../../providers/chat.provider.dart';
import '../../providers/theme-color.provider.dart';
import '../../services/contact.service.dart';
import '../../ui/snackbar.dart';
import '../chat/dm/dm-messaging.screen.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ContactService _contactService = ContactService();
  final UserRepository _userRepository = UserRepository();
  final ContactsRepository _contactsRepository = ContactsRepository();
  final ConversationRepository _conversationRepository =
      ConversationRepository();
  final ConversationMemberRepository _conversationMemberRepository =
      ConversationMemberRepository();
  List<ContactModel> _contacts = [];
  List<UserModel> _availableUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final ChatsServices _chatsServices = ChatsServices();
  AnimationController? _searchAnimationController;
  Animation<Offset>? _searchAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _searchAnimation = Tween<Offset>(begin: Offset(1.0, 0.0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _searchAnimationController!,
            curve: Curves.easeOutCubic,
          ),
        );
    _loadUsersFromLocal();
    _loadContactsAndUsers();
  }

  Future<void> _loadUsersFromLocal() async {
    try {
      final localContacts = await _contactsRepository.getAllContacts();
      if (localContacts.isNotEmpty) {
        setState(() {
          _availableUsers = localContacts;
          _filteredUsers = localContacts;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAvailableUsersAndPersist() async {
    if (_contacts.isEmpty) return;
    try {
      List<String> contactsData = getContactsForBackend();
      final response = await _userService.getAvailableUsers(contactsData);
      if (response['success'] == true && response['data'] != null) {
        List<dynamic> usersData = response['data'] is List
            ? response['data']
            : response['data']['data'] ?? [];
        List<UserModel> users = usersData
            .map((userJson) => UserModel.fromJson(userJson))
            .toList();

        // Replace local contacts DB to mirror backend
        await _contactsRepository.replaceAllContacts(users);

        if (mounted) {
          setState(() {
            _availableUsers = users;
            _filteredUsers = users;
          });
        }
      }
    } catch (_) {
      // Ignore errors; UI may still show local users
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimationController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will be called when the page becomes visible
    if (mounted) {
      _refreshDataIfNeeded();
    }
  }

  /// Called when the page becomes visible
  void onPageVisible() {
    if (mounted) {
      _refreshDataIfNeeded();
    }
  }

  /// Load both contacts and available users in sequence
  Future<void> _loadContactsAndUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First load contacts
      final contacts = await _contactService.fetchContacts();

      setState(() {
        _contacts = contacts;
      });

      // Then load available users from backend and persist to SQLite
      if (contacts.isNotEmpty) {
        await _loadAvailableUsersAndPersist();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Snack.error('Failed to load contacts: $e');
    }
  }

  /// Refresh data if needed when page becomes visible
  Future<void> _refreshDataIfNeeded() async {
    // Only refresh if we don't have data or if it's been a while
    if (_availableUsers.isEmpty && _contacts.isNotEmpty) {
      await _loadAvailableUsers();
    }
  }

  /// Get the list of fetched contacts
  List<ContactModel> get contacts => _contacts;

  /// Get contacts from the service directly
  Future<List<ContactModel>> getContactsFromService() async {
    return await _contactService.fetchContacts();
  }

  /// Get contacts in JSON format for backend API
  List<String> getContactsForBackend() {
    return _contacts.map((contact) => contact.phoneNumber).toList();
  }

  /// Load available users from backend
  Future<void> _loadAvailableUsers() async {
    if (_contacts.isEmpty) {
      return;
    }

    try {
      // Get contacts in backend format
      List<String> contactsData = getContactsForBackend();

      final response = await _userService.getAvailableUsers(contactsData);

      if (response['success'] == true) {
        // Handle both response structures: direct array or nested data
        List<dynamic> usersData = response['data'];
        List<UserModel> users = usersData
            .map((userJson) => UserModel.fromJson(userJson))
            .toList();

        setState(() {
          _availableUsers = users;
          _filteredUsers = users;
        });
      }
    } catch (e) {
      // Error loading available users
    }
  }

  /// Show find user dialog
  void _showFindUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FindUserDialog(onUserSelected: startConversation);
      },
    );
  }

  /// Toggle search mode
  void _toggleSearch() {
    if (_searchAnimationController == null) return;

    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchAnimationController!.forward();
        _searchController.clear();
        _searchQuery = '';
        _filteredUsers = _availableUsers;
      } else {
        _searchAnimationController!.reverse();
        _searchController.clear();
        _searchQuery = '';
        _filteredUsers = _availableUsers;
      }
    });
  }

  /// Perform search
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = _availableUsers;
      } else {
        _filteredUsers = _availableUsers.where((user) {
          return user.name.toLowerCase().contains(query.toLowerCase()) ||
              user.phone.contains(query);
        }).toList();
      }
    });
  }

  /// Close search
  void _closeSearch() {
    if (_searchAnimationController == null) return;

    setState(() {
      _isSearching = false;
      _searchAnimationController!.reverse();
      _searchController.clear();
      _searchQuery = '';
      _filteredUsers = _availableUsers;
    });
  }

  /// Open native phone's add contact screen
  Future<void> _openNativeAddContact() async {
    try {
      // Request permission if not already granted
      if (await FlutterContacts.requestPermission()) {
        // Open the native add contact screen
        await FlutterContacts.openExternalInsert();
      } else {
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text('Contact permission is required to add contacts'),
        //       backgroundColor: Colors.red,
        //     ),
        //   );
        // }
        Snack.error('Contact permission is required to add contacts');
      }
    } catch (e) {
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text('Failed to open add contact: $e'),
      //       backgroundColor: Colors.red,
      //     ),
      //   );
      // }
      Snack.error('Failed to open add contact: $e');
    }
  }

  void startConversation(UserModel user) async {
    final response = await _chatsServices.createChat(user.id.toString());
    if (response['success'] && response['data'] != null) {
      try {
        // store the recipient info in the user table
        await _userRepository.insertUser(user);

        // Create ConversationModel from the response
        final conversationData = response['data'];
        if (conversationData['existing'] == true) {
          final dm = await _conversationRepository.getDmByConversationId(
            conversationData['id'],
          );
          if (dm == null) {
            if (mounted) {
              Snack.show(
                'Cannot start conversation. The chat maybe deleted. Try restoring the chat.',
              );
            }
            return;
          }
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => InnerChatPage(dm: dm)),
            );
          }
          return;
        }

        final dm = DmModel(
          conversationId: conversationData['id'],
          recipientId: user.id,
          recipientName: user.name,
          recipientPhone: user.phone,
          recipientProfilePic: user.profilePic,
          unreadCount: 0,
          isRecipientOnline: user.isOnline,
          createdAt: conversationData['created_at'],
        );

        final conversation = ConversationModel(
          id: conversationData['id'],
          type: 'dm',
          unreadCount: 0,
          pinnedMessageId: null,
          createrId: conversationData['creater_id'],
          createdAt: conversationData['created_at'],
        );

        // store the conversation in local db
        await _conversationRepository.insertConversations([conversation]);

        final receiverMember = ConversationMemberModel(
          conversationId: conversationData['id'],
          userId: user.id,
          role: 'member',
          joinedAt: conversationData['created_at'],
        );

        // Store conversation members in SQLite
        await _conversationMemberRepository.insertConversationMembers([
          receiverMember,
        ]);

        final userToSave = UserModel(
          id: user.id,
          name: user.name,
          phone: user.phone,
          role: user.role,
          profilePic: user.profilePic,
          isOnline: user.isOnline,
          callAccess: user.callAccess,
        );

        await _userRepository.insertUser(userToSave);

        // Add the new DM to the chat provider state
        await ref.read(chatProvider.notifier).addNewDm(dm);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => InnerChatPage(dm: dm)),
          );
        }
      } catch (e) {
        Snack.error('Failed to start conversation: $e');
        // if (mounted) {
        //   try {
        //     final messenger = ScaffoldMessenger.maybeOf(context);
        //     if (messenger != null) {
        //       messenger.showSnackBar(
        //         _createBlurredSnackBar(
        //           message: 'Failed to start conversation: $e',
        //           backgroundColor: Colors.red,
        //           duration: Duration(seconds: 3),
        //         ),
        //       );
        //     }
        //   } catch (_) {
        //     // Context is invalid, ignore
        //   }
        // }
      }
    } else {
      Snack.error(
        'Failed to create chat: ${response['message'] ?? 'Unknown error'}',
      );
      // if (mounted) {
      //   try {
      //     final messenger = ScaffoldMessenger.maybeOf(context);
      //     if (messenger != null) {
      //       messenger.showSnackBar(
      //         _createBlurredSnackBar(
      //           message:
      //               'Failed to create chat: ${response['message'] ?? 'Unknown error'}',
      //           backgroundColor: Colors.red,
      //           duration: Duration(seconds: 3),
      //         ),
      //       );
      //     }
      //   } catch (_) {
      //     // Context is invalid, ignore
      //   }
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final themeColor = ref.watch(themeColorProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Color(0xFFF8FAFB),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: AppBar(
              backgroundColor: themeColor.primary,
              leadingWidth: 60,
              leading: Container(
                margin: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.contacts_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contacts (${_availableUsers.length})',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: _toggleSearch,
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_add_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: _openNativeAddContact,
                    tooltip: 'Add to Phone Contacts',
                  ),
                ),
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
                    onPressed: _loadContactsAndUsers,
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: themeColor.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _showFindUserDialog,
              backgroundColor: themeColor.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person_add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          body: GestureDetector(
            onTap: _isSearching ? _closeSearch : null,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFB), Color(0xFFFFFFFF)],
                ),
              ),
              child: Column(
                children: [
                  // Users list
                  // SizedBox(height: 10),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 20,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      themeColor.primary,
                                    ),
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Loading your contacts...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredUsers.isEmpty
                        ? Center(
                            child: Container(
                              margin: EdgeInsets.all(32),
                              padding: EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: themeColor.primary.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      _isSearching
                                          ? Icons.search_off_rounded
                                          : Icons.person_off_rounded,
                                      size: 48,
                                      color: themeColor.primary,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    _isSearching
                                        ? 'No search results'
                                        : 'No contacts found',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _isSearching
                                        ? 'Try searching with a different term'
                                        : 'Add contacts to start chatting',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (!_isSearching) ...[
                                    SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _showFindUserDialog,
                                      icon: Icon(Icons.person_add_rounded),
                                      label: Text('Add Contact'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: themeColor.primary,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return Container(
                                margin: EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      startConversation(user);
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: themeColor.primary
                                                      .withOpacity(0.2),
                                                  blurRadius: 12,
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              radius: 28,
                                              backgroundColor: themeColor
                                                  .primary
                                                  .withOpacity(0.1),
                                              backgroundImage:
                                                  user.profilePic != null
                                                  ? CachedNetworkImageProvider(
                                                      user.profilePic!,
                                                    )
                                                  : null,
                                              child: user.profilePic == null
                                                  ? Icon(
                                                      Icons.person_rounded,
                                                      color: themeColor.primary,
                                                      size: 28,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    color: Color(0xFF1F2937),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  user.phone,
                                                  style: TextStyle(
                                                    color: Color(0xFF6B7280),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: themeColor.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.chat_bubble_rounded,
                                              color: themeColor.primary,
                                              size: 20,
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
        ),

        // Modern Search Bar Overlay (animated) - overlaps AppBar
        if (_isSearching && _searchAnimation != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _searchAnimation!,
              child: Container(
                width: double.infinity,
                height: 70 + MediaQuery.of(context).padding.top,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 8,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: themeColor.primary,

                  boxShadow: [
                    BoxShadow(
                      color: themeColor.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: _closeSearch,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _performSearch,
                          autofocus: true,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search contacts...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? Container(
                                    margin: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _performSearch('');
                                      },
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Find User Dialog Widget
class FindUserDialog extends ConsumerStatefulWidget {
  final Function(UserModel) onUserSelected;

  const FindUserDialog({Key? key, required this.onUserSelected})
    : super(key: key);

  @override
  ConsumerState<FindUserDialog> createState() => _FindUserDialogState();
}

class _FindUserDialogState extends ConsumerState<FindUserDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final UserService _userService = UserService();
  bool _isSearching = false;
  List<UserModel> _searchResults = [];
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: screenWidth - 40, // Full width with 20px margin on each side
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.8, // Max 80% of screen height
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 0,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeColor.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_search_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Search by phone number',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isSearching
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Banner
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeColor.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: themeColor.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: themeColor.primary,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please include country code (e.g., +1, +91)',
                              style: TextStyle(
                                color: themeColor.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Phone Input
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          hintText: 'e.g., +1234567890',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Container(
                            margin: EdgeInsets.all(12),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: themeColor.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.phone_rounded,
                              color: themeColor.primary,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeColor.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        enabled: !_isSearching,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Loading Indicator
                    if (_isSearching)
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: themeColor.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  themeColor.primary,
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Searching for user...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Search Results Section
                    if (!_isSearching && _searchResults.isNotEmpty) ...[
                      Text(
                        'Search Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 12),
                      ..._searchResults
                          .map(
                            (user) => Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: themeColor.primary.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    // Handle user selection - start conversation
                                    Navigator.of(context).pop();
                                    widget.onUserSelected(user);
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: themeColor.primary
                                                    .withOpacity(0.2),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 24,
                                            backgroundColor: themeColor.primary
                                                .withOpacity(0.1),
                                            backgroundImage:
                                                user.profilePic != null
                                                ? CachedNetworkImageProvider(
                                                    user.profilePic!,
                                                  )
                                                : null,
                                            child: user.profilePic == null
                                                ? Icon(
                                                    Icons.person,
                                                    color: themeColor.primary,
                                                    size: 24,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                user.phone,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: themeColor.primary,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ],

                    // No User Found Message
                    if (!_isSearching &&
                        _searchResults.isEmpty &&
                        _errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_off,
                                color: Colors.red.shade600,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'User Not Found',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSearching
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: themeColor.primary.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Search',
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
    );
  }

  void _performSearch() async {
    if (_phoneController.text.trim().isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Please enter a phone number'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      Snack.error('Please enter a phone number');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _errorMessage = null;
    });

    try {
      final response = await _userService.getAvailableUsers([
        _phoneController.text.trim(),
      ]);

      if (response['success'] == true && response['data'] != null) {
        // Handle both response structures: direct array or nested data
        List<dynamic> usersData = response['data'] is List
            ? response['data']
            : response['data']['data'] ?? [];
        List<UserModel> users = usersData
            .map((userJson) => UserModel.fromJson(userJson))
            .toList();

        setState(() {
          _searchResults = users;
          _errorMessage = users.isEmpty
              ? 'No user found with this phone number'
              : null;
        });
      } else {
        setState(() {
          _errorMessage = '${response['message'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching user: $e';
      });
    }

    setState(() {
      _isSearching = false;
    });
  }
}
