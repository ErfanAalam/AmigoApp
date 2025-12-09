import 'package:amigo/models/conversations.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/app-colors.config.dart';
import '../../models/group.model.dart';
import '../../providers/theme-color.provider.dart';
import '../../ui/snackbar.dart';

/// Forward Message Modal widget for both DM and group chats
class ForwardMessageModal extends ConsumerStatefulWidget {
  final Set<int> messagesToForward;
  final List<DmModel>? dmList;
  final List<GroupModel>? groupList;
  final bool isLoading;
  final Function(List<int>) onForward;
  final int currentConversationId;

  const ForwardMessageModal({
    super.key,
    required this.messagesToForward,
    this.dmList,
    this.groupList,
    required this.isLoading,
    required this.onForward,
    required this.currentConversationId,
  });

  @override
  ConsumerState<ForwardMessageModal> createState() =>
      _ForwardMessageModalState();
}

class _ForwardMessageModalState extends ConsumerState<ForwardMessageModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedConversations = {};
  List<DmModel> _filteredDmList = [];
  List<GroupModel> _filteredGroupList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Initialize filtered lists
    _updateFilteredLists();

    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredLists() {
    setState(() {
      // Filter DM list - exclude current conversation
      final dmList = widget.dmList ?? [];
      _filteredDmList = dmList
          .where((dm) => dm.conversationId != widget.currentConversationId)
          .toList();

      // Filter Group list - exclude current conversation
      final groupList = widget.groupList ?? [];
      _filteredGroupList = groupList
          .where(
            (group) => group.conversationId != widget.currentConversationId,
          )
          .toList();

      // Apply search filter if query exists
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        _filteredDmList = _filteredDmList
            .where(
              (dm) =>
                  dm.recipientName.toLowerCase().contains(query) ||
                  dm.recipientPhone.toLowerCase().contains(query),
            )
            .toList();
        _filteredGroupList = _filteredGroupList
            .where((group) => group.title.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _filterConversations(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredLists();
    });
  }

  void _toggleConversationSelection(int conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
      } else {
        _selectedConversations.add(conversationId);
      }
    });
  }

  Future<void> _handleForward() async {
    if (_selectedConversations.isEmpty) {
      Snack.warning('Please select at least one chat to forward to');
      return;
    }

    // Close modal with animation
    await _slideController.reverse();
    await _fadeController.reverse();

    if (mounted) {
      Navigator.of(context).pop();
      widget.onForward(_selectedConversations.toList());
    }
  }

  Future<void> _handleCancel() async {
    await _slideController.reverse();
    await _fadeController.reverse();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) {
      return '?';
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '?';
    }

    // Filter out empty strings from split result (handles multiple spaces)
    final words = trimmedName
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.length >= 2) {
      // Both words exist and are non-empty, safe to access [0]
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      // Single word exists and is non-empty, safe to access [0]
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  Widget _buildDmAvatar(DmModel dm, ColorTheme themeColor) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: themeColor.primaryLight.withOpacity(0.3),
      backgroundImage: dm.recipientProfilePic != null
          ? CachedNetworkImageProvider(dm.recipientProfilePic!)
          : null,
      child: dm.recipientProfilePic == null
          ? Text(
              _getInitials(dm.recipientName ?? ''),
              style: TextStyle(
                color: themeColor.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
    );
  }

  Widget _buildGroupAvatar(GroupModel group) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.orange[100],
      child: Icon(Icons.group, color: Colors.orange[700], size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: SlideTransition(
            position: _slideAnimation,
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.forward,
                              color: themeColor.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Forward Message${widget.messagesToForward.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${widget.messagesToForward.length} message${widget.messagesToForward.length > 1 ? 's' : ''} selected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _handleCancel,
                              icon: Icon(Icons.close, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search chats...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[500],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onChanged: _filterConversations,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Selected count
                      if (_selectedConversations.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: themeColor.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: themeColor.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${_selectedConversations.length} selected',
                                  style: TextStyle(
                                    color: themeColor.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Conversations list
                      Expanded(
                        child: widget.isLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: themeColor.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Loading chats...'),
                                  ],
                                ),
                              )
                            : _filteredDmList.isEmpty &&
                                  _filteredGroupList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No chats available'
                                          : 'No chats found for "$_searchQuery"',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                physics: const ClampingScrollPhysics(),
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: true,
                                itemCount:
                                    _filteredDmList.length +
                                    _filteredGroupList.length +
                                    (_filteredDmList.isNotEmpty &&
                                            _filteredGroupList.isNotEmpty
                                        ? 2
                                        : 0),
                                itemBuilder: (context, index) {
                                  // Section headers
                                  if (_filteredDmList.isNotEmpty &&
                                      _filteredGroupList.isNotEmpty) {
                                    if (index == 0) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          'Direct Messages',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      );
                                    }
                                    if (index == _filteredDmList.length + 1) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          'Groups',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  // Calculate actual item index
                                  int actualIndex;
                                  bool isGroup;
                                  if (_filteredDmList.isNotEmpty &&
                                      _filteredGroupList.isNotEmpty) {
                                    // Both lists present: header(0), DMs(1 to dmLength), header(dmLength+1), Groups(dmLength+2 to end)
                                    if (index > 0 &&
                                        index <= _filteredDmList.length) {
                                      // DM items: index 1 to dmLength
                                      actualIndex = index - 1;
                                      isGroup = false;
                                    } else if (index >
                                        _filteredDmList.length + 1) {
                                      // Group items: index dmLength+2 onwards
                                      actualIndex =
                                          index - _filteredDmList.length - 2;
                                      isGroup = true;
                                    } else {
                                      // This should not happen, but return empty container as fallback
                                      return const SizedBox.shrink();
                                    }
                                  } else if (_filteredDmList.isNotEmpty) {
                                    // Only DM list
                                    actualIndex = index;
                                    isGroup = false;
                                  } else {
                                    // Only Group list
                                    actualIndex = index;
                                    isGroup = true;
                                  }

                                  // Validate indices before accessing lists
                                  if (isGroup) {
                                    if (actualIndex < 0 ||
                                        actualIndex >=
                                            _filteredGroupList.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final group =
                                        _filteredGroupList[actualIndex];
                                    final isSelected = _selectedConversations
                                        .contains(group.conversationId);

                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? themeColor.primary.withOpacity(
                                                0.1,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? themeColor.primary.withOpacity(
                                                  0.3,
                                                )
                                              : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        onTap: () =>
                                            _toggleConversationSelection(
                                              group.conversationId,
                                            ),
                                        leading: _buildGroupAvatar(group),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                group.title,
                                                style: TextStyle(
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 16,
                                                  color: isSelected
                                                      ? themeColor.primary
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[100],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.orange[300]!,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'GROUP',
                                                style: TextStyle(
                                                  color: Colors.orange[700],
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: group.lastMessageBody != null
                                            ? Text(
                                                group.lastMessageBody!,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : null,
                                        trailing: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? themeColor.primary
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? themeColor.primary
                                                  : Colors.grey[400]!,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Validate index before accessing DM list
                                    if (actualIndex < 0 ||
                                        actualIndex >= _filteredDmList.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final dm = _filteredDmList[actualIndex];
                                    final isSelected = _selectedConversations
                                        .contains(dm.conversationId);

                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? themeColor.primary.withOpacity(
                                                0.1,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? themeColor.primary.withOpacity(
                                                  0.3,
                                                )
                                              : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        onTap: () =>
                                            _toggleConversationSelection(
                                              dm.conversationId,
                                            ),
                                        leading: _buildDmAvatar(dm, themeColor),
                                        title: Text(
                                          dm.recipientName,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 16,
                                            color: isSelected
                                                ? themeColor.primary
                                                : Colors.black87,
                                          ),
                                        ),
                                        subtitle: dm.lastMessageBody != null
                                            ? Text(
                                                dm.lastMessageBody!,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : null,
                                        trailing: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? themeColor.primary
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? themeColor.primary
                                                  : Colors.grey[400]!,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                      ),

                      // Forward button
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _selectedConversations.isEmpty
                                    ? null
                                    : _handleForward,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedConversations.isEmpty
                                          ? 'Select chats to forward'
                                          : 'Forward to ${_selectedConversations.length} chat${_selectedConversations.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
