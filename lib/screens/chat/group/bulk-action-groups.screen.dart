import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../models/group.model.dart';
import '../../../providers/message.provider.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../ui/snackbar.dart';

/// Which side of the bulk operation we're about to do. Picked in phase 1
/// (BulkActionUsersPage); phase 2 (this screen) just dispatches to the
/// matching admin endpoint on confirm.
enum BulkAction { add, remove }

/// Phase 2 of the sub-admin "manage groups" flow: pick the target groups
/// for the action chosen in phase 1, then confirm.
///
/// The group list is sourced from [groupListStreamProvider] — i.e. whatever
/// groups the actor has locally — matching the user's spec: "groups that
/// sub_admin is in (or whatever groups are in his local)".
///
/// The backend silently no-ops on users not in a given group for the remove
/// path, so we don't need to pre-filter the cross-product here.
class BulkActionGroupsPage extends ConsumerStatefulWidget {
  final List<String> userIds;
  final BulkAction action;

  const BulkActionGroupsPage({
    super.key,
    required this.userIds,
    required this.action,
  });

  @override
  ConsumerState<BulkActionGroupsPage> createState() =>
      _BulkActionGroupsPageState();
}

class _BulkActionGroupsPageState extends ConsumerState<BulkActionGroupsPage> {
  final apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedGroupIds = <String>{};
  String _query = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isAdd => widget.action == BulkAction.add;

  void _toggle(String chatId) {
    setState(() {
      if (_selectedGroupIds.contains(chatId)) {
        _selectedGroupIds.remove(chatId);
      } else {
        _selectedGroupIds.add(chatId);
      }
    });
  }

  void _toggleAllVisible(List<GroupModel> visible) {
    final allSelected =
        visible.isNotEmpty &&
        visible.every((g) => _selectedGroupIds.contains(g.chatId));
    setState(() {
      if (allSelected) {
        for (final g in visible) {
          _selectedGroupIds.remove(g.chatId);
        }
      } else {
        for (final g in visible) {
          _selectedGroupIds.add(g.chatId);
        }
      }
    });
  }

  Future<void> _confirm() async {
    if (_selectedGroupIds.isEmpty) {
      Snack.warning('Select at least one group');
      return;
    }

    if (!_isAdd) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove from groups?'),
          content: Text(
            'Remove ${widget.userIds.length} user'
            '${widget.userIds.length == 1 ? '' : 's'} from '
            '${_selectedGroupIds.length} group'
            '${_selectedGroupIds.length == 1 ? '' : 's'}? '
            'Users that aren\'t in a given group are skipped automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = _isAdd
          ? await apiService.group.bulkAddMembersToGroups(
              conversationIds: _selectedGroupIds.toList(),
              userIds: widget.userIds,
            )
          : await apiService.group.bulkRemoveMembersFromGroups(
              conversationIds: _selectedGroupIds.toList(),
              userIds: widget.userIds,
            );
      final resp = result.toMap();

      if (resp['success'] == true) {
        _showSuccess(resp);
        if (mounted) {
          // Pop both phase-2 (this) and phase-1 (user picker) back to the
          // group list so the actor sees the result of the live broadcast.
          int popped = 0;
          Navigator.of(context).popUntil((_) => popped++ >= 2);
        }
      } else {
        Snack.error(resp['message']?.toString() ?? 'Operation failed');
      }
    } catch (_) {
      Snack.error('Operation failed');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Surface a meaningful summary from the per-group response data so the
  /// actor knows what actually happened (especially when some users were
  /// already-in-group / not-in-group and got silently skipped).
  void _showSuccess(Map<String, dynamic> resp) {
    final data = resp['data'] as Map<String, dynamic>?;
    final results = (data?['results'] as List<dynamic>?) ?? const [];

    if (_isAdd) {
      var totalAdded = 0;
      var totalRevived = 0;
      for (final r in results) {
        if (r is Map<String, dynamic>) {
          totalAdded += (r['added'] as List?)?.length ?? 0;
          totalRevived += (r['revived'] as List?)?.length ?? 0;
        }
      }
      final affected = totalAdded + totalRevived;
      Snack.success(
        affected == 0
            ? 'All selected users were already in the chosen groups'
            : 'Added $affected user${affected == 1 ? '' : 's'} across ${_selectedGroupIds.length} group${_selectedGroupIds.length == 1 ? '' : 's'}',
      );
    } else {
      final total = (data?['total_removed'] as num?)?.toInt() ?? 0;
      Snack.success(
        total == 0
            ? 'None of the selected users were in any of the chosen groups'
            : 'Removed $total membership${total == 1 ? '' : 's'} across ${_selectedGroupIds.length} group${_selectedGroupIds.length == 1 ? '' : 's'}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final groupsAsync = ref.watch(groupListStreamProvider);
    final title = _isAdd ? 'Add to Groups' : 'Remove from Groups';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: groupsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: themeColor.primary)),
        error: (_, __) => Center(
          child: Text(
            'Failed to load groups',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        data: (groups) {
          final filtered = _query.isEmpty
              ? groups
              : groups
                    .where((g) => g.title.toLowerCase().contains(_query))
                    .toList();
          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search groups...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${widget.userIds.length} user'
                          '${widget.userIds.length == 1 ? '' : 's'} selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        if (filtered.isNotEmpty)
                          GestureDetector(
                            onTap: () => _toggleAllVisible(filtered),
                            child: Text(
                              filtered.every(
                                    (g) => _selectedGroupIds.contains(g.chatId),
                                  )
                                  ? 'Deselect all'
                                  : 'Select all',
                              style: TextStyle(
                                fontSize: 13,
                                color: themeColor.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: Colors.grey.shade100),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          groups.isEmpty
                              ? 'You have no groups yet'
                              : 'No groups match your search',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 68,
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (_, i) {
                          final g = filtered[i];
                          final selected = _selectedGroupIds.contains(g.chatId);
                          return Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: () => _toggle(g.chatId),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.grey.shade100,
                                      backgroundImage:
                                          (g.profilePic != null &&
                                              g.profilePic!.isNotEmpty)
                                          ? CachedNetworkImageProvider(
                                              g.profilePic!,
                                            )
                                          : null,
                                      child:
                                          (g.profilePic == null ||
                                              g.profilePic!.isEmpty)
                                          ? Icon(
                                              Icons.group,
                                              color: themeColor.primary,
                                              size: 22,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        g.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? themeColor.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: selected
                                              ? themeColor.primary
                                              : Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            onPressed: _isSubmitting || _selectedGroupIds.isEmpty
                ? null
                : _confirm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isAdd
                        ? Icons.person_add_alt_1_rounded
                        : Icons.person_remove_alt_1_outlined,
                  ),
            label: Text(
              _selectedGroupIds.isEmpty
                  ? 'Confirm'
                  : 'Confirm (${_selectedGroupIds.length} group${_selectedGroupIds.length == 1 ? '' : 's'})',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _isAdd ? themeColor.primary : Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
