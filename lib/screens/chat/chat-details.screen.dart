import '../../../db/repositories/user.repo.dart';
import '../../../models/conversations.model.dart';
import '../../../models/group.model.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../types/socket.types.dart';
import '../../../utils/user.utils.dart';
import '../../../ui/snackbar.dart';
import '../../../utils/animations.utils.dart';
import 'dm/dm-media-links-docs.screen.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  final DmModel? dm;
  final GroupModel? group;

  const ChatDetailsScreen({
    super.key,
    this.dm,
    this.group,
  }) : assert(
          dm != null || group != null,
          'Either dm or group must be provided',
        );

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen> {
  final ConversationMemberRepository _conversationMemberRepo =
      ConversationMemberRepository();
  final UserRepository _userRepo = UserRepository();

  bool _isLoading = false;
  UserModel? _recipientUser;
  int? _memberCount;

  bool get isGroup => widget.group != null;
  String get conversationId =>
      widget.dm?.chatId ?? widget.group!.chatId;
  ChatType get chatType => isGroup ? ChatType.group : ChatType.dm;

  @override
  void initState() {
    super.initState();
    if (isGroup) {
      _loadGroupInfo();
    } else {
      _loadRecipientInfo();
    }
  }

  // ─── Business Logic (unchanged) ──────────────────────────────────────────

  Future<void> _loadRecipientInfo() async {
    try {
      final chatState = ref.read(chatProvider);
      try {
        final dm = chatState.dmList.firstWhere(
          (dm) => dm.chatId == widget.dm!.chatId,
        );
        final user = UserModel(
          id: dm.recipientId,
          name: dm.recipientName,
          phone: dm.recipientPhone,
          profilePic: dm.recipientProfilePic,
          isOnline: dm.isRecipientOnline,
        );
        setState(() => _recipientUser = user);
        return;
      } catch (e) {
        // DM not found in provider, continue to fallback
      }

      final currentUser = await UserUtils().getUserDetails();
      final currentUserId = currentUser?.id;
      final members = await _conversationMemberRepo
          .getActiveMembersByConversationId(widget.dm!.chatId);

      if (members.isNotEmpty && currentUserId != null) {
        for (final member in members) {
          if (member.userId != currentUserId) {
            final user = await _userRepo.getUserById(member.userId);
            if (user != null) {
              setState(() => _recipientUser = user);
              return;
            }
          }
        }
      }

      if (members.isNotEmpty && _recipientUser == null) {
        final user = await _userRepo.getUserById(members.first.userId);
        if (user != null) {
          setState(() => _recipientUser = user);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading recipient info: $e');
    }
  }

  Future<void> _loadGroupInfo() async {
    try {
      final members = await _conversationMemberRepo
          .getMembersWithUserDetailsByConversationId(conversationId);
      setState(() => _memberCount = members.length);
    } catch (e) {
      debugPrint('❌ Error loading group info: $e');
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    if (words.isNotEmpty) return words[0][0].toUpperCase();
    return '?';
  }

  String _getGroupInitials() {
    if (widget.group == null) return '?';
    final title = widget.group!.title;
    if (title.isEmpty) return '?';
    final words = title.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    if (words.isNotEmpty) return words[0][0].toUpperCase();
    return '?';
  }

  // ─── Live state helpers (read from provider, not widget) ─────────────────

  DmModel? get _liveDm {
    if (!isGroup) {
      final chatState = ref.read(chatProvider);
      try {
        return chatState.dmList.firstWhere(
          (dm) => dm.chatId == conversationId,
        );
      } catch (_) {}
    }
    return widget.dm;
  }

  GroupModel? get _liveGroup {
    if (isGroup) {
      final chatState = ref.read(chatProvider);
      try {
        return chatState.groupList.firstWhere(
          (g) => g.chatId == conversationId,
        );
      } catch (_) {}
    }
    return widget.group;
  }

  bool get _isPinned => isGroup
      ? (_liveGroup?.isPinned ?? false)
      : (_liveDm?.isPinned ?? false);

  bool get _isMuted => isGroup
      ? (_liveGroup?.isMuted ?? false)
      : (_liveDm?.isMuted ?? false);

  bool get _isFavorite => isGroup
      ? (_liveGroup?.isFavorite ?? false)
      : (_liveDm?.isFavorite ?? false);

  Future<void> _togglePin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final isPinned = _isPinned;
      final action = isPinned ? 'unpin' : 'pin';
      await ref.read(chatProvider.notifier).handleChatAction(
            action,
            conversationId,
            chatType,
          );
      setState(() => _isLoading = false);
      Snack.show(isPinned ? 'Chat unpinned' : 'Chat pinned to top');
    } catch (e) {
      setState(() => _isLoading = false);
      Snack.error('Failed to update pin status');
    }
  }

  Future<void> _toggleMute() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final isMuted = _isMuted;
      final action = isMuted ? 'unmute' : 'mute';
      await ref.read(chatProvider.notifier).handleChatAction(
            action,
            conversationId,
            chatType,
          );
      setState(() => _isLoading = false);
      Snack.show(isMuted ? 'Chat unmuted' : 'Chat muted');
    } catch (e) {
      setState(() => _isLoading = false);
      Snack.error('Failed to update mute status');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final isFavorite = _isFavorite;
      final action = isFavorite ? 'unfavorite' : 'favorite';
      await ref.read(chatProvider.notifier).handleChatAction(
            action,
            conversationId,
            chatType,
          );
      setState(() => _isLoading = false);
      Snack.show(
        isFavorite ? 'Removed from favorites' : 'Added to favorites',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      Snack.error('Failed to update favorite');
    }
  }

  Future<void> _softDeleteDm() async {
    try {
      await ref.read(chatProvider.notifier).handleChatAction(
            'delete',
            conversationId,
            chatType,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Snack.error('Failed to delete chat');
      }
    }
  }

  Future<void> _deleteChat() async {
    final chatName = isGroup
        ? widget.group!.title
        : (_recipientUser?.name ?? 'this user');

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation1,
            curve: Curves.easeOutBack,
          ),
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
                              isGroup
                                  ? Icons.delete_forever_rounded
                                  : Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: Colors.red.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isGroup ? 'Delete Group' : 'Delete Chat',
                            style: const TextStyle(
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
                                TextSpan(
                                  text: isGroup
                                      ? 'Delete the group '
                                      : 'Delete chat with ',
                                ),
                                TextSpan(
                                  text: chatName,
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
                                    'This cannot be undone. All messages will be permanently deleted.',
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
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
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
                                  Icon(Icons.delete_forever_rounded, size: 18),
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
      try {
        await ref.read(chatProvider.notifier).handleChatAction(
              'delete',
              conversationId,
              chatType,
            );
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          Snack.error('Failed to delete chat');
        }
      }
    }
  }

  void _navigateToMedia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DmMediaLinksDocsScreen(
          dm: widget.dm,
          group: widget.group,
        ),
      ),
    );
  }

  String _getCreatedAt() {
    if (isGroup) {
      return widget.group!.joinedAt;
    } else {
      return widget.dm!.createdAt;
    }
  }

  // ─── UI Helpers ──────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    final themeColor = ref.watch(themeColorProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final isOnline = !isGroup && (_recipientUser?.isOnline ?? false);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor.primary, themeColor.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        topPadding + kToolbarHeight + 8,
        24,
        44,
      ),
      child: Column(
        children: [
          // Avatar
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
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage:
                      !isGroup && _recipientUser?.profilePic != null
                      ? CachedNetworkImageProvider(
                          _recipientUser!.profilePic!,
                        )
                      : null,
                  child: isGroup
                      ? Text(
                          _getGroupInitials(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : (_recipientUser?.profilePic == null
                          ? Text(
                              _getInitials(
                                _recipientUser?.name ?? 'Unknown',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null),
                ),
                if (isOnline)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
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
          ),
          const SizedBox(height: 20),
          // Name
          Text(
            isGroup
                ? widget.group!.title
                : (_recipientUser?.name ?? 'Unknown'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isGroup && isOnline)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  isGroup
                      ? '${_memberCount ?? '...'} ${_memberCount == 1 ? 'member' : 'members'}'
                      : (isOnline ? 'Online' : 'Offline'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    bool isPinned,
    bool isMuted,
    bool isFavorite,
  ) {
    final themeColor = ref.watch(themeColorProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickAction(
              icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: isPinned ? 'Unpin' : 'Pin',
              isActive: isPinned,
              color: themeColor.primary,
              onTap: _togglePin,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildQuickAction(
              icon: isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              label: isMuted ? 'Unmute' : 'Mute',
              isActive: isMuted,
              color: themeColor.primary,
              onTap: _toggleMute,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildQuickAction(
              icon: isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              label: isFavorite ? 'Unfave' : 'Favorite',
              isActive: isFavorite,
              color: Colors.amber.shade600,
              onTap: _toggleFavorite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color.withOpacity(0.3) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(isActive),
                color: isActive ? color : Colors.grey.shade400,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? color : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaNavCard() {
    final themeColor = ref.watch(themeColorProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _navigateToMedia,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: themeColor.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Media, Links & Docs',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shared photos, videos, links and files',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final themeColor = ref.watch(themeColorProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: isGroup ? 'Joined' : 'Created',
              value: _formatDate(_getCreatedAt()),
              color: themeColor.primary,
            ),
            if (isGroup && _memberCount != null) ...[
              Divider(color: Colors.grey.shade100, height: 24),
              _buildInfoRow(
                icon: Icons.people_outline_rounded,
                label: 'Members',
                value: '$_memberCount',
                color: themeColor.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
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
                Icons.delete_outline_rounded,
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
                    isGroup ? 'Delete Group' : 'Delete Chat',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isGroup
                        ? 'Permanently delete all messages'
                        : 'Move to deleted chats',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isGroup ? _deleteChat : _softDeleteDm,
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

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch chatProvider so toggles rebuild with live state
    ref.watch(chatProvider);
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Chat Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Gradient hero header
            _buildHeroHeader(),

            // Content card
            Container(
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
                  // Drag handle indicator
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
                  const SizedBox(height: 20),

                  // Quick action toggles (Pin, Mute, Favorite)
                  StaggeredSlideFadeItem(
                    index: 0,
                    staggerDelayMs: 120,
                    child: _buildQuickActions(_isPinned, _isMuted, _isFavorite),
                  ),
                  const SizedBox(height: 20),

                  // Media navigation
                  StaggeredSlideFadeItem(
                    index: 1,
                    staggerDelayMs: 120,
                    child: _buildMediaNavCard(),
                  ),
                  const SizedBox(height: 4),

                  // Info
                  StaggeredSlideFadeItem(
                    index: 2,
                    staggerDelayMs: 120,
                    child: _buildInfoSection(),
                  ),

                  // Danger zone - DMs always, groups only for admin/creator
                  if (!isGroup || widget.group!.role == 'admin')
                    StaggeredSlideFadeItem(
                      index: 3,
                      staggerDelayMs: 120,
                      child: _buildDangerZone(),
                    ),

                  SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom + 32,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
