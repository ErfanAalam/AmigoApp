import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_service.dart';
import '../../config/app-colors.config.dart';
import '../../db/repositories/conversation-member.repo.dart';
import '../../db/repositories/conversations.repo.dart';
import '../../db/repositories/user.repo.dart';
import '../../models/conversations.model.dart';
import '../../models/group.model.dart';
import '../../models/user.model.dart';
import '../../providers/chat.provider.dart';
import '../../providers/theme-color.provider.dart';
import '../../services/user-status.service.dart';
import '../../types/socket.types.dart';
import '../../ui/blurred-dialog.widget.dart';
import '../../ui/blurred-popup.widget.dart';
import '../../ui/chat/add-member.sheet.dart';
import '../../ui/chat/group-actions.dart';
import '../../ui/snackbar.dart';
import '../../utils/animations.utils.dart';
import '../../utils/user.utils.dart';
import 'dm/dm-media-links-docs.screen.dart';
import 'dm/dm-messaging.screen.dart';

/// Telegram-style chat details. Handles both DMs (`dm`) and groups (`group`),
/// driven by which constructor arg is provided.
///
/// Layout:
///   • Light hero header — avatar, name, subtitle (member/online count or
///     last-seen), conversation ID
///   • Three quick-action cards (Message / Mute / Leave|Delete)
///   • Group members section (groups only) — Add Members row for admins,
///     then member tiles with long-press for promote/demote/remove
///   • Media nav card
///
/// Pin / favorite / "remove all members" / edit title sit in the 3-dot
/// app bar menu.
class ChatDetailsScreen extends ConsumerStatefulWidget {
  final DmModel? dm;
  final GroupModel? group;

  const ChatDetailsScreen({super.key, this.dm, this.group})
    : assert(
        dm != null || group != null,
        'Either dm or group must be provided',
      );

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen> {
  // ─── Services & repos ────────────────────────────────────────────────────
  final ConversationRepository _conversationRepo = ConversationRepository();
  final ConversationMemberRepository _memberRepo =
      ConversationMemberRepository();
  final UserRepository _userRepo = UserRepository();
  final UserUtils _userUtils = UserUtils();
  final UserStatusService _userStatusService = UserStatusService();
  final apiService = ApiService();

  // ─── State ───────────────────────────────────────────────────────────────
  bool _busy = false; // generic single-shot operation guard
  UserModel? _recipientUser; // DMs
  UserModel? _currentUser;
  String? _creatorId;
  String? _groupTitleOverride; // set after admin edits title
  List<Map<String, dynamic>> _members = const [];

  /// Active subscription to the Drift members stream — keeps the list
  /// in sync with `chat_members` / `users` table changes (which is how
  /// the chat provider applies WS `member_added` / `removed` /
  /// `promoted` / `demoted` events). Null for DMs.
  StreamSubscription<List<GroupMember>>? _membersSub;

  // Member search (groups only)
  final TextEditingController _memberSearchController =
      TextEditingController();
  String _memberSearch = '';

  // ─── Convenience getters ─────────────────────────────────────────────────
  bool get isGroup => widget.group != null;
  String get conversationId => widget.dm?.chatId ?? widget.group!.chatId;
  ChatType get chatType => isGroup ? ChatType.group : ChatType.dm;

  String get _title {
    if (isGroup) return _groupTitleOverride ?? widget.group!.title;
    return _recipientUser?.displayName ?? widget.dm?.recipientName ?? 'Unknown';
  }

  bool get _isCurrentUserAdmin {
    final id = _currentUser?.id;
    if (id == null) return false;
    for (final m in _members) {
      if (m['userId'] == id) return m['role'] == 'admin';
    }
    return false;
  }

  bool get _isCurrentUserCreator =>
      _currentUser?.id != null && _currentUser!.id == _creatorId;

  bool _isMemberCreator(String userId) =>
      _creatorId != null && userId == _creatorId;

  int get _onlineCount {
    var n = 0;
    for (final m in _members) {
      final id = m['userId'] as String?;
      if (id != null && _userStatusService.isUserOnline(id)) n++;
    }
    return n;
  }

  /// Members filtered by the current search query (case-insensitive match
  /// against display name). Sort order is whatever `_sortMembers` produced
  /// at write time — admins first, then alphabetical — so filtering
  /// preserves a stable ordering.
  List<Map<String, dynamic>> get _visibleMembers {
    final q = _memberSearch.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members.where((m) {
      final name =
          ((m['userName'] ?? m['name'] ?? '') as String).toLowerCase();
      return name.contains(q);
    }).toList();
  }

  // ─── Live state from providers (pin/mute/favorite reflect server) ───────
  DmModel? get _liveDm {
    if (isGroup) return widget.dm;
    final state = ref.read(chatProvider);
    try {
      return state.dmList.firstWhere((dm) => dm.chatId == conversationId);
    } catch (_) {
      return widget.dm;
    }
  }

  GroupModel? get _liveGroup {
    if (!isGroup) return widget.group;
    final state = ref.read(chatProvider);
    try {
      return state.groupList.firstWhere((g) => g.chatId == conversationId);
    } catch (_) {
      return widget.group;
    }
  }

  bool get _isPinned =>
      isGroup ? (_liveGroup?.isPinned ?? false) : (_liveDm?.isPinned ?? false);
  bool get _isMuted =>
      isGroup ? (_liveGroup?.isMuted ?? false) : (_liveDm?.isMuted ?? false);
  bool get _isFavorite => isGroup
      ? (_liveGroup?.isFavorite ?? false)
      : (_liveDm?.isFavorite ?? false);

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Pre-populate from `widget.group` so the hero paints synchronously.
    if (isGroup) {
      _members = _sortMembers(
        widget.group!.members
                ?.map(
                  (m) => <String, dynamic>{
                    'userId': m.userId,
                    'name': m.name,
                    'userName': m.name,
                    'profilePic': m.profilePic,
                    'role': m.role,
                    'joinedAt': m.joinedAt,
                  },
                )
                .toList() ??
            <Map<String, dynamic>>[],
      );
    }

    _memberSearchController.addListener(() {
      final q = _memberSearchController.text;
      if (q != _memberSearch) setState(() => _memberSearch = q);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.wait([
        _loadCurrentUser(),
        if (isGroup) _loadCreatorId() else _loadRecipientInfo(),
      ]);
      if (!mounted) return;
      if (isGroup) {
        // Subscribe to the live members stream — re-emits on every
        // `chat_members` / `users` change, which is how the chat
        // provider applies WS member_added/removed/promoted/demoted
        // events. Keeps the list in sync without manual refreshes.
        _membersSub = _conversationRepo
            .watchActiveGroupMembers(conversationId)
            .listen((members) {
              if (!mounted) return;
              setState(() {
                _members = _sortMembers(
                  members
                      .map(
                        (m) => <String, dynamic>{
                          'userId': m.userId,
                          'name': m.name,
                          'userName': m.name,
                          'profilePic': m.profilePic,
                          'role': m.role,
                          'joinedAt': m.joinedAt,
                        },
                      )
                      .toList(),
                );
              });
            });
        unawaited(_syncGroupInfoFromServer());
      }
    });
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    _memberSearchController.dispose();
    super.dispose();
  }

  // ─── Data loading ────────────────────────────────────────────────────────

  Future<void> _loadCurrentUser() async {
    try {
      final u = await _userUtils.getUserDetails();
      if (mounted && u != null) setState(() => _currentUser = u);
    } catch (e) {
      debugPrint('chat-details: load currentUser failed: $e');
    }
  }

  Future<void> _loadRecipientInfo() async {
    try {
      // Fast path: use the live DM model from chatProvider if available.
      try {
        final dm = ref
            .read(chatProvider)
            .dmList
            .firstWhere((d) => d.chatId == widget.dm!.chatId);
        if (mounted) {
          setState(() {
            _recipientUser = UserModel(
              id: dm.recipientId,
              name: dm.recipientName,
              phone: dm.recipientPhone,
              profilePic: dm.recipientProfilePic,
              isOnline: dm.isRecipientOnline,
            );
          });
        }
        return;
      } catch (_) {
        /* fall through to DB lookup */
      }

      final me = await _userUtils.getUserDetails();
      final myId = me?.id;
      final members = await _memberRepo.getActiveMembersByConversationId(
        widget.dm!.chatId,
      );
      if (members.isEmpty) return;

      // Pick first non-self member; fall back to first if needed.
      String? recipientId;
      for (final m in members) {
        if (m.userId != myId) {
          recipientId = m.userId;
          break;
        }
      }
      recipientId ??= members.first.userId;

      final user = await _userRepo.getUserById(recipientId);
      if (mounted && user != null) setState(() => _recipientUser = user);
    } catch (e) {
      debugPrint('chat-details: load recipient failed: $e');
    }
  }

  /// One-shot load of just the creator id — the only piece of group state
  /// that doesn't fall out of the active-members Drift stream. Members
  /// themselves are streamed via [ConversationRepository.watchActiveGroupMembers].
  Future<void> _loadCreatorId() async {
    try {
      final conv = await _conversationRepo.getConversationById(conversationId);
      if (!mounted || conv == null) return;
      setState(() => _creatorId = conv.createrId);
    } catch (e) {
      debugPrint('chat-details: load creator failed: $e');
    }
  }

  Future<void> _loadGroupInfoFromLocal() async {
    try {
      final groupInfo = await _conversationRepo.getGroupWithMembersByConvId(
        conversationId,
      );
      if (groupInfo == null) return;

      final conv = await _conversationRepo.getConversationById(conversationId);
      final members = _sortMembers(
        (groupInfo.members ?? const <GroupMember>[])
            .map(
              (m) => <String, dynamic>{
                'userId': m.userId,
                'name': m.name,
                'userName': m.name,
                'profilePic': m.profilePic,
                'role': m.role,
                'joinedAt': m.joinedAt,
              },
            )
            .toList(),
      );

      if (!mounted) return;
      setState(() {
        _members = members;
        _creatorId = conv?.createrId;
      });
    } catch (e) {
      debugPrint('chat-details: load group info failed: $e');
    }
  }

  Future<void> _syncGroupInfoFromServer() async {
    try {
      final result = await apiService.group.getGroupInfo(conversationId);
      if (!result.isSuccess || result.data == null) return;
      final data = result.data as Map<String, dynamic>;
      final raw = (data['members'] as List<dynamic>?) ?? const [];

      final users = <UserModel>[];
      final memberRows = <ConversationMemberModel>[];
      final ui = <Map<String, dynamic>>[];

      for (final m in raw) {
        if (m is! Map<String, dynamic>) continue;
        final userId = m['userId']?.toString();
        if (userId == null || userId.isEmpty) continue;
        final displayName = m['userName']?.toString() ?? '';
        final profilePic = m['userProfilePic']?.toString();
        final role = m['role']?.toString() ?? 'member';
        final joinedAt = m['joinedAt']?.toString();

        users.add(
          UserModel(
            id: userId,
            name: displayName,
            phone: m['userPhone']?.toString() ?? '',
            profilePic: profilePic,
            isOnline: false,
          ),
        );
        memberRows.add(
          ConversationMemberModel(
            chatId: conversationId,
            userId: userId,
            role: role,
            joinedAt: joinedAt,
          ),
        );
        ui.add({
          'userId': userId,
          'name': displayName,
          'userName': displayName,
          'profilePic': profilePic,
          'role': role,
          'joinedAt': joinedAt,
        });
      }

      // Persist independently — both writes can run in parallel.
      await Future.wait([
        if (users.isNotEmpty) _userRepo.insertOrUpdateUsers(users),
        if (memberRows.isNotEmpty)
          _memberRepo.insertOrUpdateConversationMembers(memberRows),
      ]);

      if (!mounted) return;
      setState(() {
        _members = _sortMembers(ui);
      });
    } catch (e) {
      debugPrint('chat-details: server sync failed: $e');
    }
  }

  /// Canonical sort applied at every entry point so the list doesn't shuffle
  /// when sources (widget.group → DB → server) disagree on order.
  /// Admins first, then alphabetical by display name.
  static List<Map<String, dynamic>> _sortMembers(
    List<Map<String, dynamic>> members,
  ) {
    members.sort((a, b) {
      final aAdmin = a['role'] == 'admin' ? 0 : 1;
      final bAdmin = b['role'] == 'admin' ? 0 : 1;
      if (aAdmin != bAdmin) return aAdmin - bAdmin;
      final aName = ((a['userName'] ?? a['name'] ?? '') as String)
          .toLowerCase();
      final bName = ((b['userName'] ?? b['name'] ?? '') as String)
          .toLowerCase();
      return aName.compareTo(bName);
    });
    return members;
  }

  // ─── Chat-level actions (pin / mute / favorite / delete / media) ────────

  Future<void> _runChatAction(String action, {String? successMsg}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(chatProvider.notifier)
          .handleChatAction(action, conversationId, chatType);
      if (successMsg != null) Snack.show(successMsg);
    } catch (_) {
      Snack.error('Action failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePin() => _runChatAction(
    _isPinned ? 'unpin' : 'pin',
    successMsg: _isPinned ? 'Chat unpinned' : 'Chat pinned',
  );

  Future<void> _toggleMute() => _runChatAction(
    _isMuted ? 'unmute' : 'mute',
    successMsg: _isMuted ? 'Chat unmuted' : 'Chat muted',
  );

  Future<void> _toggleFavorite() => _runChatAction(
    _isFavorite ? 'unfavorite' : 'favorite',
    successMsg: _isFavorite ? 'Removed from favorites' : 'Added to favorites',
  );

  Future<void> _softDeleteDm() async {
    final confirmed = await showBlurredConfirm(
      context: context,
      title: 'Delete chat?',
      message:
          'This moves your chat with $_title to Deleted Chats. You can restore it from Profile → Chat Management.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(chatProvider.notifier)
          .handleChatAction('delete', conversationId, chatType);
      // Bubble up the same payload group-delete uses so the messaging screen
      // pops itself back to the chat list.
      if (mounted) Navigator.pop(context, {'action': 'deleted'});
    } catch (_) {
      if (mounted) Snack.error('Failed to delete chat');
    }
  }

  void _navigateToMedia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DmMediaLinksDocsScreen(dm: widget.dm, group: widget.group),
      ),
    );
  }

  void _backToChat() => Navigator.pop(context);

  // ─── Group actions ───────────────────────────────────────────────────────

  Future<void> _addMembers(List<String> userIds) async {
    final ok = await addMembersToGroup(
      conversationId: conversationId,
      userIds: userIds,
    );
    if (ok && mounted) await _loadGroupInfoFromLocal();
  }

  Future<void> _promoteToAdmin(String userId, String userName) async {
    if (!_isCurrentUserAdmin) return;
    if (userId == _currentUser?.id) {
      Snack.error('You are already an admin');
      return;
    }
    final ok = await _confirm(
      title: 'Promote to admin?',
      message: '$userName will be able to add and remove members.',
      confirmLabel: 'Promote',
    );
    if (ok != true) return;

    final taskId = TaskSnack.show(message: 'Promoting $userName…');
    try {
      final res = (await apiService.group.promoteToAdmin(
        conversationId: conversationId,
        userId: userId,
      )).toMap();
      if (res['success'] == true) {
        TaskSnack.resolve(
          id: taskId,
          isSuccess: true,
          message: '$userName is now an admin',
        );
        await _memberRepo.updateMemberRole(conversationId, userId, 'admin');
        await _loadGroupInfoFromLocal();
      } else {
        TaskSnack.resolve(
          id: taskId,
          isSuccess: false,
          message: res['message']?.toString() ?? 'Failed to promote',
        );
      }
    } catch (e) {
      TaskSnack.dismiss();
      Snack.error('Error promoting member: $e');
    }
  }

  Future<void> _demoteToMember(String userId, String userName) async {
    if (!_isCurrentUserAdmin) return;
    if (_isMemberCreator(userId)) {
      Snack.error('Cannot demote the group creator');
      return;
    }
    if (userId == _currentUser?.id) {
      Snack.error('You cannot demote yourself');
      return;
    }
    final ok = await _confirm(
      title: 'Demote $userName?',
      message: 'They will lose admin privileges.',
      confirmLabel: 'Demote',
    );
    if (ok != true) return;

    final taskId = TaskSnack.show(message: 'Demoting $userName…');
    try {
      final res = (await apiService.group.demoteToMember(
        conversationId: conversationId,
        userId: userId,
      )).toMap();
      if (res['success'] == true) {
        TaskSnack.resolve(
          id: taskId,
          isSuccess: true,
          message: '$userName demoted to member',
        );
        await _memberRepo.updateMemberRole(conversationId, userId, 'member');
        await _loadGroupInfoFromLocal();
      } else {
        TaskSnack.resolve(
          id: taskId,
          isSuccess: false,
          message: res['message']?.toString() ?? 'Failed to demote',
        );
      }
    } catch (e) {
      TaskSnack.dismiss();
      Snack.error('Error demoting member: $e');
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    if (!_isCurrentUserAdmin) return;
    if (_isMemberCreator(userId)) {
      Snack.error('Cannot remove the group creator');
      return;
    }
    if (userId == _currentUser?.id) {
      Snack.error('Use Leave to exit the group');
      return;
    }
    final ok = await _confirm(
      title: 'Remove $userName?',
      message: 'They will no longer be a member of this group.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (ok != true) return;

    try {
      final res = (await apiService.group.removeMember(
        conversationId: conversationId,
        userId: userId,
      )).toMap();
      if (res['success'] == true) {
        Snack.success('$userName removed from group');
        await _memberRepo.deleteMemberByConversationAndUserId(
          conversationId,
          userId,
        );
        await _loadGroupInfoFromLocal();
      } else {
        Snack.error(res['message']?.toString() ?? 'Failed to remove member');
      }
    } catch (e) {
      Snack.error('Error removing member: $e');
    }
  }

  Future<void> _removeAllMembers() async {
    if (!_isCurrentUserCreator) {
      Snack.error('Only the group creator can do this');
      return;
    }
    final toRemove = _members
        .where((m) => !_isMemberCreator(m['userId']))
        .toList();
    if (toRemove.isEmpty) {
      Snack.show('No members to remove');
      return;
    }
    final ok = await _confirm(
      title: 'Remove all members?',
      message:
          'This will remove ${toRemove.length} member${toRemove.length == 1 ? '' : 's'} from the group. The creator will remain.',
      confirmLabel: 'Remove all',
      destructive: true,
    );
    if (ok != true) return;

    final taskId = TaskSnack.show(message: 'Removing all members…');
    var removedCount = 0;
    var failedCount = 0;
    for (final m in toRemove) {
      final id = m['userId'].toString();
      try {
        final res = (await apiService.group.removeMember(
          conversationId: conversationId,
          userId: id,
        )).toMap();
        if (res['success'] == true) {
          removedCount++;
          await _memberRepo.deleteMemberByConversationAndUserId(
            conversationId,
            id,
          );
        } else {
          failedCount++;
        }
      } catch (_) {
        failedCount++;
      }
    }
    TaskSnack.resolve(
      id: taskId,
      isSuccess: removedCount > 0,
      message: failedCount > 0
          ? '$removedCount removed, $failedCount failed'
          : 'All members removed',
    );
    if (mounted) await _loadGroupInfoFromLocal();
  }

  Future<void> _deleteGroup() async {
    final ok = await confirmAndDeleteGroup(
      context: context,
      ref: ref,
      conversationId: conversationId,
      groupTitle: _title,
    );
    if (ok && mounted) Navigator.pop(context, {'action': 'deleted'});
  }

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _title);
    final newTitle = await showBlurredDialog<String>(
      context: context,
      title: 'Edit group name',
      body: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 50,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Group name',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
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
            borderSide: const BorderSide(color: Color(0xFF1F6FEB), width: 1.5),
          ),
        ),
      ),
      footer: BlurredDialogActions(
        cancelLabel: 'Cancel',
        confirmLabel: 'Save',
        onCancel: (ctx) => Navigator.of(ctx).pop(),
        onConfirm: (ctx) => Navigator.of(ctx).pop(controller.text.trim()),
      ),
    );
    if (newTitle == null || newTitle.isEmpty || newTitle == _title) return;

    final taskId = TaskSnack.show(message: 'Updating group name…');
    try {
      final res = (await apiService.group.updateGroupTitle(
        title: newTitle,
        conversationId: conversationId,
      )).toMap();
      if (res['success'] == true) {
        if (mounted) setState(() => _groupTitleOverride = newTitle);
        TaskSnack.resolve(
          id: taskId,
          isSuccess: true,
          message: 'Group name updated',
        );
      } else {
        TaskSnack.resolve(
          id: taskId,
          isSuccess: false,
          message: res['message']?.toString() ?? 'Failed to update name',
        );
      }
    } catch (e) {
      TaskSnack.dismiss();
      Snack.error('Error updating name: $e');
    }
  }

  // ─── Add Member sheet ────────────────────────────────────────────────────

  Future<void> _showAddMemberSheet() async {
    if (!_isCurrentUserAdmin) return;
    final selected = await showAddMemberSheet(
      context: context,
      existingMemberIds: _members.map((m) => m['userId'].toString()).toSet(),
      themeColor: ref.read(themeColorProvider),
    );
    if (selected != null && selected.isNotEmpty) {
      await _addMembers(selected);
    }
  }

  // ─── Member long-press menu ──────────────────────────────────────────────

  Future<void> _showMemberMenu(
    BuildContext anchor,
    Map<String, dynamic> member,
    Offset tapPosition,
  ) async {
    final userId = member['userId'].toString();
    final userName = (member['userName'] ?? member['name'] ?? '') as String;
    if (userId == _currentUser?.id) return; // no self-actions

    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox;
    final isAdmin = member['role'] == 'admin';
    final canManage = _isCurrentUserAdmin && !_isMemberCreator(userId);

    final messageLabel = userName.isNotEmpty
        ? 'Message $userName'
        : 'Message';

    final selected = await showBlurredPopup<_MemberAction>(
      context: anchor,
      // Anchor the popup to the user's finger — a small rect at the
      // tap-down position lets the layout delegate place the popup
      // exactly where they pressed.
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      // Tap is somewhere in the middle of the screen; growing from the
      // top-left corner reads naturally for a finger-anchored menu.
      scaleAlignment: Alignment.topLeft,
      items: [
        BlurredPopupAction(
          value: _MemberAction.message,
          label: messageLabel,
          icon: Icons.chat_bubble_outline_rounded,
        ),
        if (canManage) ...[
          const BlurredPopupSeparator(),
          if (isAdmin)
            const BlurredPopupAction(
              value: _MemberAction.demote,
              label: 'Remove admin',
              icon: Icons.person_outline_rounded,
            )
          else
            const BlurredPopupAction(
              value: _MemberAction.promote,
              label: 'Make admin',
              icon: Icons.shield_outlined,
            ),
          const BlurredPopupSeparator(),
          const BlurredPopupAction(
            value: _MemberAction.remove,
            label: 'Remove from group',
            icon: Icons.person_remove_outlined,
            style: BlurredPopupActionStyle.destructive,
          ),
        ],
      ],
    );

    switch (selected) {
      case _MemberAction.message:
        await _messageMember(member);
        break;
      case _MemberAction.promote:
        await _promoteToAdmin(userId, userName);
        break;
      case _MemberAction.demote:
        await _demoteToMember(userId, userName);
        break;
      case _MemberAction.remove:
        await _removeMember(userId, userName);
        break;
      case null:
        break;
    }
  }

  /// Open (or create) a DM with the given group member, mirroring the
  /// flow used by the contacts screen's `startConversation`.
  Future<void> _messageMember(Map<String, dynamic> member) async {
    final userId = member['userId'].toString();
    if (userId.isEmpty || userId == _currentUser?.id) return;

    // Prefer the locally cached user (has phone, role, etc.); fall back
    // to a minimal model built from the group-member map.
    UserModel? user = await _userRepo.getUserById(userId);
    user ??= UserModel(
      id: userId,
      name: (member['userName'] ?? member['name'] ?? '') as String,
      phone: '',
      profilePic: member['profilePic'] as String?,
      isOnline: _userStatusService.isUserOnline(userId),
    );

    try {
      final result = await apiService.chat.createChat(userId);
      if (!result.isSuccess || result.data == null) {
        Snack.error('Failed to start chat: ${result.message}');
        return;
      }

      await _userRepo.insertUser(user);

      final data = result.data as Map<String, dynamic>;
      final convId = data['id']?.toString() ?? '';

      if (data['existing'] == true) {
        final dm = await _conversationRepo.getDmByConversationId(convId);
        if (!mounted) return;
        if (dm == null) {
          Snack.show(
            'Cannot start conversation. The chat may be deleted. Try restoring the chat.',
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InnerChatPage(dm: dm)),
        );
        return;
      }

      final dm = DmModel(
        chatId: convId,
        recipientId: user.id,
        recipientName: user.displayName,
        recipientPhone: user.phone,
        recipientProfilePic: user.profilePic,
        unreadCount: 0,
        isRecipientOnline: user.isOnline,
        createdAt: data['created_at']?.toString() ?? '',
      );

      final conversation = ConversationModel(
        id: convId,
        type: 'dm',
        unreadCount: 0,
        createrId: data['creater_id']?.toString(),
        createdAt: data['created_at']?.toString(),
      );

      await _conversationRepo.insertConversations([conversation]);
      await _memberRepo.insertConversationMembers([
        ConversationMemberModel(
          chatId: convId,
          userId: user.id,
          role: 'member',
          joinedAt: data['created_at']?.toString(),
        ),
      ]);
      await ref.read(chatProvider.notifier).addNewDm(dm);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InnerChatPage(dm: dm)),
      );
    } catch (e) {
      Snack.error('Failed to start chat: $e');
    }
  }

  // ─── Generic confirm dialog ──────────────────────────────────────────────

  /// Thin wrapper over [showBlurredConfirm] kept on the state class so the
  /// existing call sites (`_confirm(title: …, message: …)`) need no edits.
  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) {
    return showBlurredConfirm(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Subscribe to chatProvider so toggles rebuild with live state.
    ref.watch(chatProvider);
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (isGroup && _isCurrentUserAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit group name',
              onPressed: _editTitle,
            ),
          BlurredPopupButton<String>(
            icon: Icons.more_vert,
            iconColor: Colors.black87,
            menuMaxWidth: 220,
            tooltip: 'More',
            itemsBuilder: () {
              // DMs always show Delete (soft-delete → moves to "deleted
              // chats"). Groups only show Delete for admin/creator —
              // regular members no longer have a destructive action here.
              final canDelete = !isGroup || _isCurrentUserAdmin || _isCurrentUserCreator;
              return [
                BlurredPopupAction(
                  value: 'favorite',
                  label: _isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  icon: _isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                ),
                if (isGroup && _isCurrentUserCreator)
                  const BlurredPopupAction(
                    value: 'clear',
                    label: 'Remove all members',
                    icon: Icons.group_remove_outlined,
                    style: BlurredPopupActionStyle.destructive,
                  ),
                if (canDelete) ...[
                  const BlurredPopupSeparator(),
                  BlurredPopupAction(
                    value: 'delete',
                    label: isGroup ? 'Delete group' : 'Delete chat',
                    icon: Icons.delete_outline_rounded,
                    style: BlurredPopupActionStyle.destructive,
                  ),
                ],
              ];
            },
            onSelected: (v) {
              switch (v) {
                case 'favorite':
                  _toggleFavorite();
                  break;
                case 'clear':
                  _removeAllMembers();
                  break;
                case 'delete':
                  if (isGroup) {
                    _deleteGroup();
                  } else {
                    _softDeleteDm();
                  }
                  break;
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroHeader(themeColor),
            const SizedBox(height: 16),
            StaggeredSlideFadeItem(
              index: 0,
              staggerDelayMs: 80,
              child: _buildActionCards(themeColor),
            ),
            if (isGroup) ...[
              const SizedBox(height: 12),
              StaggeredSlideFadeItem(
                index: 1,
                staggerDelayMs: 80,
                child: _buildMembersSection(themeColor),
              ),
            ],
            const SizedBox(height: 12),
            StaggeredSlideFadeItem(
              index: isGroup ? 2 : 1,
              staggerDelayMs: 80,
              child: _buildMediaNavCard(themeColor),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero header ─────────────────────────────────────────────────────────

  Widget _buildHeroHeader(ColorTheme themeColor) {
    final subtitle = _heroSubtitle();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Column(
        children: [
          _HeroAvatar(
            title: _title,
            isGroup: isGroup,
            profilePic: !isGroup ? _recipientUser?.profilePic : null,
            color: themeColor.primary,
            highlight: themeColor.primaryLight,
          ),
          const SizedBox(height: 14),
          Text(
            _title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          // const SizedBox(height: 2),
          // GestureDetector(
          //   onTap: _copyConversationId,
          //   child: Text(
          //     'ID: $conversationId',
          //     style: TextStyle(
          //       fontSize: 12,
          //       color: Colors.grey.shade500,
          //       letterSpacing: 0.2,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  String _heroSubtitle() {
    if (isGroup) {
      final n = _members.length;
      final online = _onlineCount;
      final base = '$n member${n == 1 ? '' : 's'}';
      return online > 0 ? '$base, $online online' : base;
    }
    final user = _recipientUser;
    if (user == null) return ' ';
    if (user.isOnline) return 'online';
    return user.phone.isNotEmpty ? user.phone : 'offline';
  }

  // ─── Action cards row ────────────────────────────────────────────────────

  Widget _buildActionCards(ColorTheme themeColor) {
    final third = _thirdActionCard(themeColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              color: Colors.black87,
              onTap: _backToChat,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionCard(
              icon: _isMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
              label: _isMuted ? 'Unmute' : 'Mute',
              color: Colors.black87,
              onTap: _busy ? null : _toggleMute,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: third),
        ],
      ),
    );
  }

  Widget _thirdActionCard(ColorTheme themeColor) {
    // Pin/Unpin lives in the action row for everyone (DMs and groups,
    // every role). The destructive Delete action moved to the 3-dot
    // menu — see app bar above.
    return _ActionCard(
      icon: _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
      label: _isPinned ? 'Unpin' : 'Pin',
      color: _isPinned ? themeColor.primary : Colors.black87,
      onTap: _busy ? null : _togglePin,
    );
  }

  // ─── Members section ─────────────────────────────────────────────────────

  Widget _buildMembersSection(ColorTheme themeColor) {
    final visible = _visibleMembers;
    final searching = _memberSearch.trim().isNotEmpty;
    // Search bar only appears once the group is big enough to warrant it —
    // tiny groups read better as a flat list.
    final showSearch = _members.length >= 5 || searching;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
        child: Column(
          children: [
            if (_isCurrentUserAdmin) _buildAddMembersRow(themeColor),
            if (showSearch) _buildMemberSearchField(themeColor),
            if ((_isCurrentUserAdmin || showSearch) && _members.isNotEmpty)
              Divider(height: 1, indent: 64, color: Colors.grey.shade100),
            if (visible.isEmpty && searching)
              _buildNoMatchState(themeColor)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 64,
                  color: Colors.grey.shade100,
                ),
                itemBuilder: (context, i) {
                  final member = visible[i];
                  return _buildMemberTile(member, themeColor);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMembersRow(ColorTheme themeColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        onTap: _showAddMemberSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: themeColor.primaryLight.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: themeColor.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Add Members',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: themeColor.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberSearchField(ColorTheme themeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: _memberSearchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search members',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade500,
            size: 20,
          ),
          suffixIcon: _memberSearch.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade500,
                    size: 18,
                  ),
                  onPressed: () => _memberSearchController.clear(),
                  splashRadius: 18,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF2F3F5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: themeColor.primary, width: 1.4),
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildNoMatchState(ColorTheme themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'No members match "${_memberSearch.trim()}"',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, ColorTheme themeColor) {
    final userId = member['userId'].toString();
    final userName =
        (member['userName'] ?? member['name'] ?? 'Unknown') as String;
    final profilePic = member['profilePic'] as String?;
    final role = member['role'] as String?;
    final isAdmin = role == 'admin';
    final isCreator = _isMemberCreator(userId);
    final isMe = userId == _currentUser?.id;
    final isOnline = _userStatusService.isUserOnline(userId);

    Offset tapPosition = Offset.zero;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (d) => tapPosition = d.globalPosition,
        onLongPress: () {
          HapticFeedback.lightImpact();
          _showMemberMenu(context, member, tapPosition);
        },
        onTap: () {
          // Long-press is the discoverable interaction; tap is a no-op for now.
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: themeColor.primaryLight.withOpacity(0.25),
                backgroundImage: (profilePic != null && profilePic.isNotEmpty)
                    ? CachedNetworkImageProvider(profilePic)
                    : null,
                child: (profilePic == null || profilePic.isEmpty)
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: themeColor.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '$userName (You)' : userName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline ? 'online' : 'offline',
                      style: TextStyle(
                        fontSize: 13,
                        color: isOnline
                            ? const Color(0xFF2196F3)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCreator)
                _RoleBadge(label: 'Owner', color: Colors.deepPurple)
              else if (isAdmin)
                _RoleBadge(label: 'Admin', color: themeColor.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Media nav card ──────────────────────────────────────────────────────

  Widget _buildMediaNavCard(ColorTheme themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  const Expanded(
                    child: Text(
                      'Media, Links & Docs',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero avatar widget ────────────────────────────────────────────────────

class _HeroAvatar extends StatelessWidget {
  final String title;
  final bool isGroup;
  final String? profilePic;
  final Color color;
  final Color highlight;

  const _HeroAvatar({
    required this.title,
    required this.isGroup,
    required this.profilePic,
    required this.color,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(title);
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, color],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: profilePic != null && profilePic!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: profilePic!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _avatarText(initials),
                errorWidget: (_, __, ___) => _avatarText(initials),
              ),
            )
          : _avatarText(initials),
    );
  }

  Widget _avatarText(String initials) => Center(
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 38,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words[0].isNotEmpty ? words[0][0].toUpperCase() : '?';
  }
}

// ─── Action card widget ────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
              Icon(
                icon,
                color: disabled ? Colors.grey.shade400 : color,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: disabled ? Colors.grey.shade400 : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Role badge (Owner / Admin) ────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _MemberAction { message, promote, demote, remove }
