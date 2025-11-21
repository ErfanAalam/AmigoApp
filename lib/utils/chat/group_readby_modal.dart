import 'package:amigo/db/repositories/messageStatus.repo.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/models/message_status.model.dart';
import 'package:amigo/models/user_model.dart';
import 'package:amigo/types/socket.type.dart' hide MessageStatusType;
import 'package:flutter/material.dart';

/// Helper class to combine UserModel with status timestamps
class MemberWithStatus {
  final UserModel user;
  final String? deliveredAt;
  final String? readAt;

  MemberWithStatus({required this.user, this.deliveredAt, this.readAt});
}

/// ReadBy Modal Widget with smooth animations and good UI/UX
/// Shows which group members have read a message and which haven't
class ReadByModal extends StatefulWidget {
  final MessageModel message;
  final List<UserModel> members;
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
  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();
  List<MemberWithStatus> readMembers = [];
  List<MemberWithStatus> deliveredMembers = [];
  bool isLoading = true;

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Load all members with their read and delivered statuses
  Future<void> _loadMembersWithStatus() async {
    setState(() {
      isLoading = true;
      readMembers = [];
      deliveredMembers = [];
    });

    // Get all statuses for this message
    final allStatuses = await _messageStatusRepo.getMessageStatusesByMessageId(
      widget.message.id,
    );

    // Create a map of userId -> status for quick lookup
    final statusMap = <int, MessageStatusType>{};
    for (final status in allStatuses) {
      statusMap[status.userId] = status;
    }

    // Separate members into read and delivered (but not read)
    for (final member in widget.members) {
      // Skip the current user if they're the sender
      if (widget.currentUserId != null && member.id == widget.currentUserId) {
        continue;
      }

      final status = statusMap[member.id];
      if (status != null) {
        if (status.readAt != null) {
          // Member has read the message
          readMembers.add(
            MemberWithStatus(
              user: member,
              deliveredAt: status.deliveredAt,
              readAt: status.readAt,
            ),
          );
        } else if (status.deliveredAt != null) {
          // Member has delivered but not read
          deliveredMembers.add(
            MemberWithStatus(
              user: member,
              deliveredAt: status.deliveredAt,
              readAt: null,
            ),
          );
        }
      }
    }

    // Sort by timestamp (most recent first)
    readMembers.sort((a, b) {
      if (a.readAt == null && b.readAt == null) return 0;
      if (a.readAt == null) return 1;
      if (b.readAt == null) return -1;
      return b.readAt!.compareTo(a.readAt!);
    });

    deliveredMembers.sort((a, b) {
      if (a.deliveredAt == null && b.deliveredAt == null) return 0;
      if (a.deliveredAt == null) return 1;
      if (b.deliveredAt == null) return -1;
      return b.deliveredAt!.compareTo(a.deliveredAt!);
    });

    setState(() {
      isLoading = false;
    });
  }

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

    // Load members with status
    _loadMembersWithStatus();
  }

  void _closeModal() async {
    await _fadeController.reverse();
    await _slideController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      // Parse the timestamp and convert to local time
      final dateTime = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // Format hour in 12-hour format
      int hour12 = dateTime.hour == 0
          ? 12
          : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday $hour12:$minute $period';
      } else if (difference.inDays < 7) {
        final weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        final weekday = weekdays[dateTime.weekday - 1];
        return '$weekday $hour12:$minute $period';
      } else {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final month = months[dateTime.month - 1];
        final day = dateTime.day;
        final year = dateTime.year;
        return '$month $day, $year $hour12:$minute $period';
      }
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                                          isLoading
                                              ? 'Loading...'
                                              : '${readMembers.length} read, ${deliveredMembers.length} delivered',
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
                                        widget.message.body?.isNotEmpty ?? false
                                            ? widget.message.body!
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

                        // Loading indicator
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          )
                        else ...[
                          // Read members section
                          if (readMembers.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Read by ${readMembers.length}',
                              true,
                            ),
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
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

                          // Delivered members section
                          if (deliveredMembers.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Delivered (not read) ${deliveredMembers.length}',
                              false,
                            ),
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: deliveredMembers.length,
                                itemBuilder: (context, index) {
                                  return _buildMemberTile(
                                    deliveredMembers[index],
                                    false,
                                    index + readMembers.length,
                                  );
                                },
                              ),
                            ),
                          ],

                          // Empty state
                          if (readMembers.isEmpty && deliveredMembers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No status information available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
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
    MemberWithStatus memberWithStatus,
    bool hasRead,
    int index,
  ) {
    final user = memberWithStatus.user;
    final name = user.name;
    final profilePic = user.profilePic;

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
                    width: 48,
                    height: 48,
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
                        const SizedBox(height: 4),
                        if (hasRead && memberWithStatus.readAt != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.done_all,
                                    size: 14,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Read ${_formatTimestamp(memberWithStatus.readAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (memberWithStatus.deliveredAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Delivered ${_formatTimestamp(memberWithStatus.deliveredAt)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          )
                        else if (memberWithStatus.deliveredAt != null)
                          Row(
                            children: [
                              Icon(
                                Icons.done,
                                size: 14,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Delivered ${_formatTimestamp(memberWithStatus.deliveredAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Not delivered yet',
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
                      hasRead ? Icons.check_circle : Icons.schedule,
                      color: Colors.white,
                      size: 18,
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
      case MessageType.image:
        return '📷 Image';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.document:
        return '📄 Document';
      case MessageType.audio:
        return '🎵 Voice Message';
      default:
        return 'Message';
    }
  }
}
