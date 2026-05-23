import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../config/app-colors.config.dart';
import '../../../models/user.model.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/contact.service.dart';
import '../../../ui/snackbar.dart';
import '../../../utils/animations.utils.dart';
import '../../../utils/user.utils.dart';
import 'bulk-action-groups.screen.dart';

/// Phase 1 of the sub-admin "manage groups" flow: pick users + action.
///
/// The actor selects which users they want to act on (with helpers for
/// "all staff" / "all regular users"), then taps "Add to groups" or
/// "Remove from groups" — that pushes [BulkActionGroupsPage] where they
/// choose target groups and confirm. The actual write happens server-side
/// from phase 2; this screen only collects the user_ids.
class BulkActionUsersPage extends ConsumerStatefulWidget {
  const BulkActionUsersPage({super.key});

  @override
  ConsumerState<BulkActionUsersPage> createState() =>
      _BulkActionUsersPageState();
}

class _BulkActionUsersPageState extends ConsumerState<BulkActionUsersPage> {
  final apiService = ApiService();
  final ContactService _contactService = ContactService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allContacts = [];
  List<UserModel> _filteredContacts = [];
  final Set<String> _selectedIds = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_allContacts);
      } else {
        _filteredContacts = _allContacts
            .where(
              (u) =>
                  u.displayName.toLowerCase().contains(query) ||
                  u.phone.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  /// Source of truth is `get-available-users` — same endpoint as the
  /// create-group contact picker, so the actor sees the exact set of users
  /// they have in their phone contacts that are also on Amigo, with `role`
  /// attached for the staff/user filter chips.
  Future<void> _loadContacts() async {
    try {
      final contacts = await _contactService.fetchContacts();
      final phones = contacts.map((c) => c.phoneNumber).toList();
      final resp = (await apiService.user.getAvailableUsers(phones)).toMap();

      List<UserModel> users = [];
      if (resp['success'] == true && resp['data'] != null) {
        users = (resp['data'] as List<dynamic>)
            .map((u) => UserModel.fromJson(u))
            .toList();
        users = await UserUtils().enrichUsersWithDisplayNames(users);
        users.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _allContacts = users;
        _filteredContacts = List.from(users);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Snack.error('Failed to load contacts');
    }
  }

  void _toggle(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  void _selectAllStaff() {
    setState(() {
      _selectedIds.addAll(
        _filteredContacts
            .where((u) => (u.role ?? '').toLowerCase() == 'staff')
            .map((u) => u.id),
      );
    });
  }

  /// "Regular users" — excludes staff/admin/sub_admin. Matches how the
  /// dashboard surfaces the role taxonomy.
  void _selectAllUsers() {
    setState(() {
      _selectedIds.addAll(
        _filteredContacts
            .where((u) => (u.role ?? 'user').toLowerCase() == 'user')
            .map((u) => u.id),
      );
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  void _proceed(BulkAction action) {
    if (_selectedIds.isEmpty) {
      Snack.warning('Select at least one user first');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BulkActionGroupsPage(
          userIds: _selectedIds.toList(),
          action: action,
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final count = _selectedIds.length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Select Users',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: themeColor.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _QuickActionChip(
                        label: 'Select all staff',
                        icon: Icons.badge_outlined,
                        color: themeColor.primary,
                        onTap: _selectAllStaff,
                      ),
                      _QuickActionChip(
                        label: 'Select all users',
                        icon: Icons.people_alt_outlined,
                        color: themeColor.primary,
                        onTap: _selectAllUsers,
                      ),
                      if (count > 0)
                        _QuickActionChip(
                          label: 'Clear ($count)',
                          icon: Icons.clear_all_rounded,
                          color: Colors.grey.shade700,
                          onTap: _clearSelection,
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade100),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: themeColor.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : _filteredContacts.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredContacts.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 68,
                      color: Colors.grey.shade100,
                    ),
                    itemBuilder: (context, i) {
                      final user = _filteredContacts[i];
                      return _ContactTile(
                        index: i,
                        user: user,
                        isSelected: _selectedIds.contains(user.id),
                        initials: _initials(user.displayName),
                        themeColor: themeColor,
                        onTap: () => _toggle(user.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: count == 0
          ? null
          : SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _proceed(BulkAction.remove),
                        icon: const Icon(Icons.person_remove_alt_1_outlined),
                        label: Text('Remove from groups ($count)'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.red.withAlpha(15),
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.withAlpha(0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _proceed(BulkAction.add),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text('Add to groups ($count)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: themeColor.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.red.withAlpha(0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _allContacts.isEmpty
                ? 'No contacts found on Amigo'
                : 'No contacts match your search',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withOpacity(0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final int index;
  final UserModel user;
  final bool isSelected;
  final String initials;
  final ColorTheme themeColor;
  final VoidCallback onTap;

  const _ContactTile({
    required this.index,
    required this.user,
    required this.isSelected,
    required this.initials,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isStaff = (user.role ?? '').toLowerCase() == 'staff';
    return StaggeredSlideFadeItem(
      index: index,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isSelected
                      ? themeColor.primaryLight.withOpacity(0.3)
                      : Colors.grey.shade100,
                  backgroundImage: user.profilePic != null
                      ? NetworkImage(user.profilePic!)
                      : null,
                  child: user.profilePic == null
                      ? Text(
                          initials,
                          style: TextStyle(
                            color: isSelected
                                ? themeColor.primary
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isStaff)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Staff',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        user.phone,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? themeColor.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? themeColor.primary
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
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
      ),
    );
  }
}
