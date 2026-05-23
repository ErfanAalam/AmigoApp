import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_service.dart';
import '../../config/app-colors.config.dart';
import '../../db/repositories/conversation-member.repo.dart';
import '../../db/repositories/conversations.repo.dart';
import '../../db/repositories/user.repo.dart';
import '../../db/sqlite.schema.dart';
import '../../models/conversations.model.dart';
import '../../models/group.model.dart';
import '../../models/user.model.dart';
import '../../providers/chat.provider.dart';
import '../../providers/message.provider.dart';
import '../../providers/theme-color.provider.dart';
import '../../services/socket/ws-message.handler.dart';
import '../../services/user-status.service.dart';
import '../../types/socket.types.dart';
import '../../ui/blurred-dialog.widget.dart';
import '../../ui/blurred-popup.widget.dart';
import '../../ui/chat/add-member.sheet.dart';
import '../../ui/chat/group-actions.dart';
import '../../ui/snackbar.dart';
import '../../utils/animations.utils.dart';
import '../../utils/chat/mute-duration-picker.util.dart';
import '../../utils/user.utils.dart';
import 'dm/dm-media-links-docs.screen.dart';
import 'dm/dm-messaging.screen.dart';
import 'starred-messages.screen.dart';

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
  bool _uploadingPfp = false; // group pfp upload in-flight
  UserModel? _recipientUser; // DMs
  UserModel? _currentUser;
  String? _creatorId;
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _members = const [];

  /// Active subscription to the Drift members stream — keeps the list
  /// in sync with `chat_members` / `users` table changes (which is how
  /// the chat provider applies WS `member_added` / `removed` /
  /// `promoted` / `demoted` events). Null for DMs.
  StreamSubscription<List<GroupMember>>? _membersSub;

  /// Disappearing-messages duration on this chat. Loaded from local DB on
  /// init and kept in sync via [_disappearingSub] when peers change it.
  /// null = feature off.
  int? _disappearingAfterSec;
  StreamSubscription<ConversationDisappearingPayload>? _disappearingSub;

  // Member search (groups only)
  final TextEditingController _memberSearchController = TextEditingController();
  String _memberSearch = '';

  // ─── Convenience getters ─────────────────────────────────────────────────
  bool get isGroup => widget.group != null;
  String get conversationId => widget.dm?.chatId ?? widget.group!.chatId;
  ChatType get chatType => isGroup ? ChatType.group : ChatType.dm;

  /// Title resolved against the live `chats` row when available — drops back
  /// to the in-memory widget snapshot during the very first paint while the
  /// stream is still loading. Reading off the row is what lets WS-driven
  /// `chat_details:update` events update the hero text live.
  ///
  /// Non-reactive: getters use `ref.read`, so call sites in event handlers
  /// (dialog text, snackbar messages) see the current value but don't
  /// rebuild on change. The hero header in `build()` uses `ref.watch`
  /// directly so it does redraw on every emit.
  String _resolveTitle(Chat? live) {
    if (isGroup) {
      final liveTitle = live?.title;
      if (liveTitle != null && liveTitle.isNotEmpty) return liveTitle;
      return widget.group!.title;
    }
    return _recipientUser?.displayName ?? widget.dm?.recipientName ?? 'Unknown';
  }

  String? _resolveGroupProfilePic(Chat? live) {
    if (!isGroup) return null;
    return live?.profilePic ?? widget.group?.profilePic;
  }

  String get _title {
    final live = ref.read(chatByIdStreamProvider(conversationId)).value;
    return _resolveTitle(live);
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
      final name = ((m['userName'] ?? m['name'] ?? '') as String).toLowerCase();
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
  String? get _mutedUntil =>
      isGroup ? _liveGroup?.mutedUntil : _liveDm?.mutedUntil;
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

    // Subscribe to remote disappearing-setting changes so the tile updates
    // when a peer toggles the duration. The WS handler has already persisted
    // the new value into the conversations table by the time this fires.
    _disappearingSub = WebSocketMessageHandler().conversationDisappearingStream
        .where((p) => p.convId == conversationId)
        .listen((p) {
          if (!mounted) return;
          setState(() => _disappearingAfterSec = p.durationSec);
        });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.wait([
        _loadCurrentUser(),
        _loadDisappearingSetting(),
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
    _disappearingSub?.cancel();
    _memberSearchController.dispose();
    super.dispose();
  }

  // ─── Disappearing-messages ───────────────────────────────────────────────

  Future<void> _loadDisappearingSetting() async {
    try {
      final conv = await _conversationRepo.getConversationById(conversationId);
      if (!mounted) return;
      setState(() => _disappearingAfterSec = conv?.disappearingAfterSec);
    } catch (e) {
      debugPrint('chat-details: load disappearing failed: $e');
    }
  }

  /// Pre-defined durations matching the backend's ALLOWED_DURATIONS set.
  /// Order matters — drives the picker layout (off → shortest → longest).
  ///
  /// TEMPORARY: the 2-minute row exists to make the feature testable in a
  /// single sitting — verifies the sweeper fan-out, view-layer filter, and
  /// chat_meta refresh end-to-end. Remove before GA along with the matching
  /// 120s entry in disappearing.service.ts:ALLOWED_DURATIONS.
  static const List<({int? sec, String label})> _disappearingOptions = [
    (sec: null, label: 'Off'),
    // (sec: 120, label: '2 minutes (test)'),
    (sec: 24 * 60 * 60, label: '24 hours'),
    (sec: 7 * 24 * 60 * 60, label: '7 days'),
    (sec: 90 * 24 * 60 * 60, label: '90 days'),
  ];

  String _disappearingLabelFor(int? sec) {
    for (final o in _disappearingOptions) {
      if (o.sec == sec) return o.label;
    }
    return 'Custom';
  }

  Future<void> _onTapDisappearing(ColorTheme themeColor) async {
    final current = _disappearingAfterSec;
    final picked = await showModalBottomSheet<({int? sec, bool clear})>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Disappearing messages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'New messages sent to this chat will disappear after the '
                'selected duration. Already-sent messages are not affected.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 12),
            for (final o in _disappearingOptions)
              RadioListTile<int?>(
                value: o.sec,
                groupValue: current,
                onChanged: (v) => Navigator.of(ctx).pop((sec: v, clear: false)),
                title: Text(o.label),
                activeColor: themeColor.primary,
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;
    if (picked.sec == current) return; // no-op

    setState(() => _busy = true);
    final result = await apiService.chat.setChatDisappearing(
      conversationId: conversationId,
      durationSec: picked.sec,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    final ok = result.isSuccess;
    if (ok) {
      // Server broadcasts the change back, but our own session won't see the
      // WS echo (it's broadcast-only to the conversation). Apply locally too.
      setState(() => _disappearingAfterSec = picked.sec);
      try {
        await _conversationRepo.setDisappearingAfterSec(
          conversationId,
          picked.sec,
        );
      } catch (e) {
        debugPrint('chat-details: persist disappearing failed: $e');
      }
    } else {
      Snack.error('Could not update disappearing messages');
    }
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
      // Resolve recipientId from chatProvider's in-memory list when present
      // (cheap), otherwise fall back to the chat_members table.
      String? recipientId;
      try {
        final dm = ref
            .read(chatProvider)
            .dmList
            .firstWhere((d) => d.chatId == widget.dm!.chatId);
        recipientId = dm.recipientId;
        // First-paint placeholder while the repo lookup is in flight. The
        // recipientName here may be the raw server name (chatProvider builds
        // DMs from backend JSON before the contacts join exists), so the
        // repo lookup below is required to fill `contactName`.
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
      } catch (_) {
        final me = await _userUtils.getUserDetails();
        final myId = me?.id;
        final members = await _memberRepo.getActiveMembersByConversationId(
          widget.dm!.chatId,
        );
        if (members.isEmpty) return;

        for (final m in members) {
          if (m.userId != myId) {
            recipientId = m.userId;
            break;
          }
        }
        recipientId ??= members.first.userId;
      }

      // Authoritative load via the repo so the joined `contactName` field is
      // populated — this is what makes `displayName` reflect the local
      // contact rename instead of the server name.
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

  Future<void> _runChatAction(
    String action, {
    String? successMsg,
    DateTime? muteUntil,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(chatProvider.notifier)
          .handleChatAction(
            action,
            conversationId,
            chatType,
            muteUntil: muteUntil,
          );
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

  // Muted → unmuted asks for confirmation first (with the auto-unmute time);
  // unmuted → muted opens the duration picker.
  Future<void> _toggleMute() async {
    if (_isMuted) {
      final confirmed = await showUnmuteConfirmation(
        context: context,
        mutedUntilIso: _mutedUntil,
      );
      if (confirmed != true || !mounted) return;
      await _runChatAction('unmute', successMsg: 'Chat unmuted');
      return;
    }
    final choice = await showMuteDurationPicker(context);
    if (choice == null || !mounted) return;
    await _runChatAction(
      'mute',
      muteUntil: choice.until,
      successMsg: choice.isForever ? 'Chat muted' : 'Chat muted until ${_formatMuteUntil(choice.until!)}',
    );
  }

  String _formatMuteUntil(DateTime until) {
    final local = until.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hh:$mm';
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

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
        // Optimistic local DB write so the editor sees the new title even
        // before the server's chat_details:update WS event lands. Drift
        // watchers re-emit → AppBars / hero text repaint. The WS event is
        // idempotent and writes the same value again.
        try {
          await _conversationRepo.updateChatTitle(conversationId, newTitle);
        } catch (_) {
          /* best-effort */
        }
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

  // ─── Group profile picture (admin only) ──────────────────────────────────

  /// Show source picker and upload the chosen image as the group's avatar.
  /// On success: optimistic local DB write for instant feedback, then the
  /// chat_details:update WS event re-applies the change to every member's
  /// local DB (idempotent).
  Future<void> _pickAndUploadGroupPfp() async {
    if (!isGroup || !_isCurrentUserAdmin || _uploadingPfp) return;
    final source = await _showImageSourceSheet();
    if (source == null) return;
    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPfp = true);
    final taskId = TaskSnack.show(message: 'Updating group photo…');
    try {
      final res = await apiService.group.updateGroupProfileImage(
        conversationId: conversationId,
        image: File(picked.path),
      );
      final map = res.toMap();
      if (map['success'] == true) {
        final newUrl =
            (map['data'] as Map<String, dynamic>?)?['profile_pic'] as String?;
        // Optimistic local DB write — Drift watchers re-emit so the hero
        // updates without waiting for the WS round-trip.
        if (newUrl != null && newUrl.isNotEmpty) {
          try {
            await _conversationRepo.updateChatProfilePic(
              conversationId,
              newUrl,
            );
          } catch (_) {
            /* best-effort */
          }
        }
        TaskSnack.resolve(
          id: taskId,
          isSuccess: true,
          message: 'Group photo updated',
        );
      } else {
        TaskSnack.resolve(
          id: taskId,
          isSuccess: false,
          message: map['message']?.toString() ?? 'Failed to update photo',
        );
      }
    } catch (e) {
      TaskSnack.dismiss();
      Snack.error('Error updating photo: $e');
    } finally {
      if (mounted) setState(() => _uploadingPfp = false);
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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

    final messageLabel = userName.isNotEmpty ? 'Message $userName' : 'Message';

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
              final canDelete =
                  !isGroup || _isCurrentUserAdmin || _isCurrentUserCreator;
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
              child: _buildDisappearingNavCard(themeColor),
            ),
            const SizedBox(height: 12),
            StaggeredSlideFadeItem(
              index: isGroup ? 3 : 2,
              staggerDelayMs: 80,
              child: _buildMediaNavCard(themeColor),
            ),
            const SizedBox(height: 12),
            StaggeredSlideFadeItem(
              index: isGroup ? 4 : 3,
              staggerDelayMs: 80,
              child: _buildStarredNavCard(themeColor),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToStarred() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StarredMessagesScreen(
          chatId: conversationId,
          chatTitle: _resolveTitle(null),
        ),
      ),
    );
  }

  Widget _buildStarredNavCard(ColorTheme themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            onTap: _navigateToStarred,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.star_outline_rounded,
                      color: themeColor.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Starred Messages',
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

  // ─── Hero header ─────────────────────────────────────────────────────────

  Widget _buildHeroHeader(ColorTheme themeColor) {
    final subtitle = _heroSubtitle();
    // Reactive read — the hero rebuilds when chat_details:update writes a
    // new title/profilePic into local DB.
    final liveChat = ref.watch(chatByIdStreamProvider(conversationId)).value;
    final title = _resolveTitle(liveChat);
    final groupPic = _resolveGroupProfilePic(liveChat);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Column(
        children: [
          _HeroAvatar(
            title: title,
            isGroup: isGroup,
            profilePic: isGroup ? groupPic : _recipientUser?.profilePic,
            color: themeColor.primary,
            highlight: themeColor.primaryLight,
            // Editable only when the current user is a group admin. Tap
            // opens the source sheet → upload → optimistic DB write.
            onTap: (isGroup && _isCurrentUserAdmin)
                ? (_uploadingPfp ? null : _pickAndUploadGroupPfp)
                : null,
            isUploading: _uploadingPfp,
          ),
          const SizedBox(height: 14),
          Text(
            title,
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
          borderRadius: BorderRadius.circular(20),
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
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 64, color: Colors.grey.shade100),
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
          Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade400),
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

  // ─── Disappearing-messages nav card ──────────────────────────────────────

  Widget _buildDisappearingNavCard(ColorTheme themeColor) {
    final isOn = _disappearingAfterSec != null;
    final trailingLabel = _disappearingLabelFor(_disappearingAfterSec);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            onTap: _busy ? null : () => _onTapDisappearing(themeColor),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      color: themeColor.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Disappearing messages',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    trailingLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: isOn ? themeColor.primary : Colors.grey.shade500,
                      fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 6),
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

  // ─── Media nav card ──────────────────────────────────────────────────────

  Widget _buildMediaNavCard(ColorTheme themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            onTap: _navigateToMedia,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(50),
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
  // Non-null only for admins of the current group — taps open the source
  // sheet to pick/upload a new pfp. When null, the avatar is non-interactive.
  final VoidCallback? onTap;
  final bool isUploading;

  const _HeroAvatar({
    required this.title,
    required this.isGroup,
    required this.profilePic,
    required this.color,
    required this.highlight,
    this.onTap,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(title);
    final avatar = Container(
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

    final editable = onTap != null;
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Tap target wraps the whole 100x100 avatar — Material+InkWell
          // gives a subtle ripple for the admin tap affordance.
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: avatar,
            ),
          ),
          if (isUploading)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.35),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          if (editable && !isUploading)
            Positioned(
              right: 7,
              bottom: 7,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(Icons.camera_alt_rounded, size: 16, color: color),
              ),
            ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
