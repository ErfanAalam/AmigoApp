import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/conversation_model.dart';

/// Forward Message Modal widget for both DM and group chats
class ForwardMessageModal extends StatefulWidget {
  final Set<int> messagesToForward;
  final List<ConversationModel> availableConversations;
  final bool isLoading;
  final Function(List<int>) onForward;
  final int currentConversationId;

  const ForwardMessageModal({
    super.key,
    required this.messagesToForward,
    required this.availableConversations,
    required this.isLoading,
    required this.onForward,
    required this.currentConversationId,
  });

  @override
  State<ForwardMessageModal> createState() => _ForwardMessageModalState();
}

class _ForwardMessageModalState extends State<ForwardMessageModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedConversations = {};
  List<ConversationModel> _filteredConversations = [];
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

    // Initialize filtered conversations
    _filteredConversations = widget.availableConversations;

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

  void _filterConversations(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredConversations = widget.availableConversations;
      } else {
        _filteredConversations = widget.availableConversations
            .where(
              (conv) =>
                  conv.displayName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one chat to forward to'),
          backgroundColor: Colors.orange,
        ),
      );
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
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  Widget _buildConversationAvatar(ConversationModel conversation) {
    if (conversation.isGroup) {
      // Group conversation - show group icon
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.orange[100],
        child: Icon(Icons.group, color: Colors.orange[700], size: 28),
      );
    } else {
      // DM conversation - show user avatar or initials
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.teal[100],
        backgroundImage: conversation.displayAvatar != null
            ? CachedNetworkImageProvider(conversation.displayAvatar!)
            : null,
        child: conversation.displayAvatar == null
            ? Text(
                _getInitials(conversation.displayName),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            Icon(Icons.forward, color: Colors.teal, size: 28),
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
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${_selectedConversations.length} selected',
                                  style: TextStyle(
                                    color: Colors.teal[700],
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
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.teal,
                                    ),
                                    SizedBox(height: 16),
                                    Text('Loading chats...'),
                                  ],
                                ),
                              )
                            : _filteredConversations.isEmpty
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
                                itemCount: _filteredConversations.length,
                                itemBuilder: (context, index) {
                                  final conversation =
                                      _filteredConversations[index];
                                  final isSelected = _selectedConversations
                                      .contains(conversation.conversationId);

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.teal.withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.teal.withOpacity(0.3)
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () => _toggleConversationSelection(
                                        conversation.conversationId,
                                      ),
                                      leading: _buildConversationAvatar(
                                        conversation,
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              conversation.displayName,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                fontSize: 16,
                                                color: isSelected
                                                    ? Colors.teal[700]
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (conversation.isGroup)
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
                                      subtitle:
                                          conversation
                                                  .metadata
                                                  ?.lastMessage
                                                  .body !=
                                              null
                                          ? Text(
                                              conversation
                                                  .metadata!
                                                  .lastMessage
                                                  .body,
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
                                              ? Colors.teal
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.teal
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
                                  backgroundColor: Colors.teal,
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
