import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../api/api_service.dart';
import '../../config/app-colors.config.dart';
import '../../db/repositories/conversation-member.repo.dart';
import '../../models/conversations.model.dart';
import '../../models/user.model.dart';
import '../../services/contact.service.dart';
import '../../utils/user.utils.dart';
import '../snackbar.dart';

/// Shows the "Add members" bottom sheet, returns the list of selected
/// user IDs once the user taps Add. Returns `null` if the sheet was
/// dismissed without adding anyone.
///
/// The sheet self-fetches available contacts; the caller only needs to
/// pass the conversation context and the IDs of users already in the
/// group (so they can be filtered out of the picker).
Future<List<String>?> showAddMemberSheet({
  required BuildContext context,
  required Set<String> existingMemberIds,
  required ColorTheme themeColor,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMemberSheet(
      existingMemberIds: existingMemberIds,
      themeColor: themeColor,
    ),
  );
}

/// Calls the add-members API and writes the new rows to local SQLite.
/// Returns `true` on success. Caller is responsible for refreshing any
/// in-memory member list that depends on the local DB.
Future<bool> addMembersToGroup({
  required String conversationId,
  required List<String> userIds,
}) async {
  if (userIds.isEmpty) return false;
  final taskId = TaskSnack.show(message: 'Adding members…');
  try {
    final res = (await ApiService().group.addMember(
      conversationId: conversationId,
      userIds: userIds,
    ))
        .toMap();

    if (res['success'] == true) {
      TaskSnack.resolve(
        id: taskId,
        isSuccess: true,
        message: 'Members added',
      );
      final rows = userIds
          .map(
            (id) => ConversationMemberModel(
              chatId: conversationId,
              userId: id,
              role: 'member',
              joinedAt: DateTime.now().toIso8601String(),
            ),
          )
          .toList();
      await ConversationMemberRepository().insertConversationMembers(rows);
      return true;
    }

    TaskSnack.resolve(
      id: taskId,
      isSuccess: false,
      message: res['message']?.toString() ?? 'Failed to add members',
    );
    return false;
  } catch (e) {
    TaskSnack.dismiss();
    Snack.error('Error adding members: $e');
    return false;
  }
}

class _AddMemberSheet extends StatefulWidget {
  final Set<String> existingMemberIds;
  final ColorTheme themeColor;

  const _AddMemberSheet({
    required this.existingMemberIds,
    required this.themeColor,
  });

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _api = ApiService();
  final _contactService = ContactService();
  final _userUtils = UserUtils();
  final _searchController = TextEditingController();
  final Set<String> _selected = {};

  bool _loading = true;
  String _search = '';
  List<UserModel> _users = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_search != _searchController.text) {
        setState(() => _search = _searchController.text);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final contacts = await _contactService.fetchContacts();
      if (contacts.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final phones = contacts.map((c) => c.phoneNumber).toList();
      final res = (await _api.user.getAvailableUsers(phones)).toMap();
      if (res['success'] == true && res['data'] != null) {
        final usersData = res['data'] as List<dynamic>;
        final users = usersData
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        final enriched =
            await _userUtils.enrichUsersWithDisplayNames(users);
        // Drop users already in the group so the picker only shows
        // genuinely-addable contacts.
        final available = enriched
            .where((u) => !widget.existingMemberIds.contains(u.id))
            .toList();
        available.sort(
          (a, b) =>
              a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        );
        if (mounted) setState(() => _users = available);
      }
    } catch (e) {
      debugPrint('AddMemberSheet load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<UserModel> get _filtered {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase().trim();
    return _users.where((u) {
      return u.displayName.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
    }).toList();
  }

  bool get _areAllFilteredSelected {
    if (_filtered.isEmpty) return false;
    return _filtered.every((u) => _selected.contains(u.id));
  }

  void _selectAllFiltered() {
    setState(() {
      _selected.addAll(_filtered.map((u) => u.id));
    });
  }

  void _deselectAllFiltered() {
    setState(() {
      for (final u in _filtered) {
        _selected.remove(u.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeColor;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Members',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _selected.isEmpty
                            ? '${_users.length} contacts available'
                            : '${_selected.length} selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: _selected.isEmpty
                              ? Colors.grey.shade500
                              : theme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
            ),
          ),
          if (!_loading && _filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _areAllFilteredSelected
                        ? _deselectAllFiltered
                        : _selectAllFiltered,
                    child: Text(
                      _areAllFilteredSelected ? 'Deselect all' : 'Select all',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _filtered.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 68,
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (_, i) {
                          final u = _filtered[i];
                          final selected = _selected.contains(u.id);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selected.remove(u.id);
                                } else {
                                  _selected.add(u.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        theme.primaryLight.withOpacity(0.3),
                                    backgroundImage: u.profilePic != null
                                        ? CachedNetworkImageProvider(
                                            u.profilePic!,
                                          )
                                        : null,
                                    child: u.profilePic == null
                                        ? Text(
                                            u.displayName.isNotEmpty
                                                ? u.displayName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: theme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.displayName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          u.phone,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? theme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: selected
                                            ? theme.primary
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () =>
                        Navigator.pop(context, _selected.toList()),
                    child: Text(
                      'Add ${_selected.length} member${_selected.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            _search.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty
                ? 'No contacts found'
                : 'No contacts available to add',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
