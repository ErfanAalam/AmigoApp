import 'package:flutter/material.dart';
import '../../models/message_model.dart';

/// ReadBy Modal Widget with smooth animations and good UI/UX
/// Shows which group members have read a message and which haven't
class ReadByModal extends StatefulWidget {
  final MessageModel message;
  final List<Map<String, dynamic>> members;
  final int? currentUserId;

  const ReadByModal({
    super.key,
    required this.message,
    required this.members,
    this.currentUserId,
  });

  @override
  State<ReadByModal> createState() => _ReadByModalState();
}

class _ReadByModalState extends State<ReadByModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Initialize animations
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Get members who have read the message
  List<Map<String, dynamic>> _getReadMembers() {
    final readMembers = <Map<String, dynamic>>[];

    for (final member in widget.members) {
      final lastReadMessageId = member['last_read_message_id'];
      final userId = member['user_id'];

      // Skip current user
      if (userId == widget.currentUserId) continue;

      // Check if member has read this message or a later one
      if (lastReadMessageId != null) {
        final lastReadId = lastReadMessageId is int
            ? lastReadMessageId
            : int.tryParse(lastReadMessageId.toString());

        if (lastReadId != null && lastReadId >= widget.message.id) {
          readMembers.add(member);
        }
      }
    }

    return readMembers;
  }

  /// Get members who haven't read the message
  List<Map<String, dynamic>> _getUnreadMembers() {
    final unreadMembers = <Map<String, dynamic>>[];

    for (final member in widget.members) {
      final lastReadMessageId = member['last_read_message_id'];
      final userId = member['user_id'];

      // Skip current user
      if (userId == widget.currentUserId) continue;

      // Check if member hasn't read this message
      if (lastReadMessageId == null) {
        unreadMembers.add(member);
      } else {
        final lastReadId = lastReadMessageId is int
            ? lastReadMessageId
            : int.tryParse(lastReadMessageId.toString());

        if (lastReadId == null || lastReadId < widget.message.id) {
          unreadMembers.add(member);
        }
      }
    }

    return unreadMembers;
  }

  void _closeModal() async {
    await _fadeController.reverse();
    await _slideController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final readMembers = _getReadMembers();
    final unreadMembers = _getUnreadMembers();

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
          child: GestureDetector(
            onTap: _closeModal,
            child: Container(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping on modal content
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.mark_chat_read_rounded,
                                      color: Colors.teal[600],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Read By',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        Text(
                                          '${readMembers.length} of ${widget.members.length - 1} members',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _closeModal,
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),

                              // Message preview
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.teal[400],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        widget.message.body.isNotEmpty
                                            ? widget.message.body
                                            : _getMessageTypeText(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Read members section
                        if (readMembers.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Read by ${readMembers.length}',
                            true,
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: readMembers.length,
                              itemBuilder: (context, index) {
                                return _buildMemberTile(
                                  readMembers[index],
                                  true,
                                  index,
                                );
                              },
                            ),
                          ),
                        ],

                        // Unread members section
                        if (unreadMembers.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Not read by ${unreadMembers.length}',
                            false,
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: unreadMembers.length,
                              itemBuilder: (context, index) {
                                return _buildMemberTile(
                                  unreadMembers[index],
                                  false,
                                  index + readMembers.length,
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isRead) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: isRead ? Colors.green[400] : Colors.orange[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isRead ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    Map<String, dynamic> member,
    bool hasRead,
    int index,
  ) {
    final name = member['name']?.toString() ?? 'Unknown User';
    final profilePic = member['profile_pic']?.toString();
    final lastReadMessageId = member['last_read_message_id'];

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasRead ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasRead ? Colors.green[200]! : Colors.orange[200]!,
                ),
              ),
              child: Row(
                children: [
                  // Profile picture or initials
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasRead ? Colors.green[100] : Colors.orange[100],
                      shape: BoxShape.circle,
                    ),
                    child: profilePic != null && profilePic.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              profilePic,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildInitials(name);
                              },
                            ),
                          )
                        : _buildInitials(name),
                  ),

                  const SizedBox(width: 12),

                  // Name and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (hasRead && lastReadMessageId != null)
                          Text(
                            'Read at message #$lastReadMessageId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Text(
                            'Not read yet',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasRead ? Colors.green[400] : Colors.orange[400],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasRead ? Icons.check : Icons.schedule,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .map((word) => word.isNotEmpty ? word[0] : '')
              .take(2)
              .join('')
              .toUpperCase()
        : 'U';

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  String _getMessageTypeText() {
    switch (widget.message.type) {
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎥 Video';
      case 'document':
        return '📄 Document';
      case 'audios':
        return '🎵 Voice Message';
      default:
        return 'Message';
    }
  }
}
