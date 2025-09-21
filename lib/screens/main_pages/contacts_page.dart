import 'package:amigo/screens/main_pages/inner_chat_page.dart';
import 'package:flutter/material.dart';
import '../../models/contact_model.dart';
import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/contact_service.dart';
import '../../api/user.service.dart';
import '../../api/chats.services.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ContactService _contactService = ContactService();
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
    _loadContactsAndUsers();
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

      // Then load available users if we have contacts
      if (contacts.isNotEmpty) {
        await _loadAvailableUsers();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load contacts: $e');
    }
  }

  /// Refresh data if needed when page becomes visible
  Future<void> _refreshDataIfNeeded() async {
    // Only refresh if we don't have data or if it's been a while
    if (_availableUsers.isEmpty && _contacts.isNotEmpty) {
      await _loadAvailableUsers();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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

      if (response['success'] == true && response['data'] != null) {
        // Handle both response structures: direct array or nested data
        List<dynamic> usersData = response['data'] is List
            ? response['data']
            : response['data']['data'] ?? [];
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

  /// Send contacts to backend for filtering
  Future<void> syncContactsWithBackend() async {
    if (_contacts.isEmpty) {
      _showErrorSnackBar('No contacts to sync');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      await _loadAvailableUsers();

      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Contacts synced with backend successfully!');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to sync contacts: $e');
    }
  }

  /// Show find user dialog
  void _showFindUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FindUserDialog(onUserSelected: _startConversationFromDialog);
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

  void _startConversationFromDialog(UserModel user) async {
    final response = await _chatsServices.createChat(user.id.toString());
    if (response['success'] && response['data'] != null) {
      try {
        // Create ConversationModel from the response
        final conversationData = response['data'];
        final conversation = ConversationModel(
          conversationId:
              conversationData['id'] ?? conversationData['conversationId'] ?? 0,
          type: 'direct',
          unreadCount: 0,
          joinedAt: DateTime.now().toIso8601String(),
          userId: user.id,
          userName: user.name,
          userProfilePic: user.profilePic,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InnerChatPage(conversation: conversation),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create chat: ${response['message'] ?? 'Unknown error'}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void startConversation(String userId) async {
    final response = await _chatsServices.createChat(userId);
    if (response['success'] && response['data'] != null) {
      try {
        // Find the user info for this conversation
        final userInfo = _availableUsers.firstWhere(
          (user) => user.id.toString() == userId,
          orElse: () => UserModel(
            id: int.tryParse(userId) ?? 0,
            name: 'Unknown User',
            phone: '',
            profilePic: null,
          ),
        );

        // Create ConversationModel from the response
        final conversationData = response['data'];
        final conversation = ConversationModel(
          conversationId:
              conversationData['id'] ?? conversationData['conversationId'] ?? 0,
          type: 'direct',
          unreadCount: 0,
          joinedAt: DateTime.now().toIso8601String(),
          userId: userInfo.id,
          userName: userInfo.name,
          userProfilePic: userInfo.profilePic,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InnerChatPage(conversation: conversation),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create chat: ${response['message'] ?? 'Unknown error'}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leadingWidth: 40, // Reduce leading width to minimize gap
            leading: Padding(
              padding: EdgeInsets.only(left: 16), // Add some left padding
              child: Icon(Icons.people, color: Colors.white),
            ),
            titleSpacing: 8, // Reduce spacing between leading and title
            title: Text(
              'Contacts',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            backgroundColor: Colors.teal,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: Colors.white),
                onPressed: _showFindUserDialog,
              ),
              IconButton(
                icon: Icon(Icons.search, color: Colors.white),
                onPressed: _toggleSearch,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadContactsAndUsers,
              ),
            ],
          ),
          body: GestureDetector(
            onTap: _isSearching ? _closeSearch : null,
            child: Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                  // Header section (always visible)
                  // Container(
                  //   width: double.infinity,
                  //   padding: EdgeInsets.only(
                  //     top: 30,
                  //     bottom: 20,
                  //     left: 20,
                  //     right: 20,
                  //   ),
                  //   decoration: BoxDecoration(
                  //     borderRadius: BorderRadius.only(
                  //       bottomLeft: Radius.circular(20),
                  //       bottomRight: Radius.circular(20),
                  //     ),
                  //     gradient: LinearGradient(
                  //       begin: Alignment.topCenter,
                  //       end: Alignment.bottomCenter,
                  //       colors: [Colors.teal, Colors.teal[300]!],
                  //     ),
                  //   ),
                  //   child: Column(
                  //     children: [
                  //       Icon(Icons.people, size: 60, color: Colors.white),
                  //       SizedBox(height: 12),
                  //       Text(
                  //         'Available Users',
                  //         style: TextStyle(
                  //           fontSize: 24,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.white,
                  //         ),
                  //       ),
                  //       SizedBox(height: 8),
                  //       Text(
                  //         _isLoading
                  //             ? 'Loading users...'
                  //             : '${_availableUsers.length} users found',
                  //         style: TextStyle(color: Colors.white70, fontSize: 16),
                  //       ),
                  //       SizedBox(height: 16),
                  //       Row(
                  //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  //         children: [
                  //           ElevatedButton(
                  //             onPressed: _loadContactsAndUsers,
                  //             style: ElevatedButton.styleFrom(
                  //               backgroundColor: Colors.white,
                  //               foregroundColor: Colors.teal,
                  //               padding: EdgeInsets.symmetric(
                  //                 horizontal: 20,
                  //                 vertical: 12,
                  //               ),
                  //             ),
                  //             child: Text(
                  //               _contacts.isNotEmpty
                  //                   ? 'Refresh Users'
                  //                   : 'Fetch Contacts',
                  //             ),
                  //           ),
                  //           ElevatedButton.icon(
                  //             onPressed: _showFindUserDialog,
                  //             icon: Icon(Icons.add, size: 18),
                  //             label: Text('Add User'),
                  //             style: ElevatedButton.styleFrom(
                  //               backgroundColor: Colors.teal[100],
                  //               foregroundColor: Colors.teal[800],
                  //               padding: EdgeInsets.symmetric(
                  //                 horizontal: 20,
                  //                 vertical: 12,
                  //               ),
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),

                  // Users list
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.teal,
                              ),
                            ),
                          )
                        : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isSearching
                                      ? Icons.search_off
                                      : Icons.person_off,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  _isSearching
                                      ? 'No search results'
                                      : 'No users found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _isSearching
                                      ? 'Try searching with a different term'
                                      : 'Make sure you have contacts and they are synced',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.teal[100],
                                    backgroundImage: user.profilePic != null
                                        ? NetworkImage(user.profilePic!)
                                        : null,
                                    child: user.profilePic == null
                                        ? Icon(
                                            Icons.person,
                                            color: Colors.teal[700],
                                            size: 30,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    user.phone,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.teal[300],
                                    size: 16,
                                  ),
                                  onTap: () {
                                    // Handle user tap if needed
                                    startConversation(user.id.toString());
                                  },
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

        // Search Bar Overlay (animated) - overlaps AppBar
        if (_isSearching && _searchAnimation != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _searchAnimation!,
              child: Container(
                width: double.infinity,
                height: kToolbarHeight + MediaQuery.of(context).padding.top,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  bottom: 0,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(color: Colors.teal),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _performSearch,
                        autofocus: true,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone number...',
                          contentPadding: EdgeInsets.only(bottom: 20),
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.search, color: Colors.white),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.white),
                                  onPressed: () {
                                    _searchController.clear();
                                    _performSearch('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.white,
                              width: 0.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
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
class FindUserDialog extends StatefulWidget {
  final Function(UserModel) onUserSelected;

  const FindUserDialog({Key? key, required this.onUserSelected})
    : super(key: key);

  @override
  State<FindUserDialog> createState() => _FindUserDialogState();
}

class _FindUserDialogState extends State<FindUserDialog> {
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.teal, Colors.teal.shade600],
                ),
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
                          Icons.search,
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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please include country code (e.g., +1, +91)',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.phone,
                              color: Colors.teal,
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
                              color: Colors.teal,
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
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.teal,
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
                                border: Border.all(color: Colors.teal.shade200),
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
                                                color: Colors.teal.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 24,
                                            backgroundColor:
                                                Colors.teal.shade100,
                                            backgroundImage:
                                                user.profilePic != null
                                                ? NetworkImage(user.profilePic!)
                                                : null,
                                            child: user.profilePic == null
                                                ? Icon(
                                                    Icons.person,
                                                    color: Colors.teal.shade700,
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
                                          Icons.arrow_forward_ios,
                                          color: Colors.teal.shade400,
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
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: Colors.teal.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 20),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.red,
        ),
      );
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
