import 'package:amigo/ui/blurred-dialog.widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme-color.provider.dart';
import '../../services/auth/auth.service.dart';
import '../../ui/app-bar.widget.dart';
import '../../ui/settings-tile.widget.dart';
import '../../utils/user.utils.dart';
import '../auth/login.screen.dart';
import '../profile/edit-profile.screen.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await UserUtils().getUserDetails();
    if (!mounted) return;
    setState(() {
      _user = u?.toJson();
      _loading = false;
    });
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      const months = [
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
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  void _openEditProfile() {
    if (_user == null) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, _, __) => EditProfileModal(
        userData: _user!,
        onProfileUpdated: (updatedData) {
          if (!mounted) return;
          setState(() => _user = updatedData);
        },
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    // final themeColor = ref.read(themeColorProvider);
    final shouldLogout = await showBlurredConfirm(
      context: context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
      confirmIcon: Icons.logout_rounded,
      destructive: true,
    );
    // final shouldLogout = await showDialog<bool>(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     shape: RoundedRectangleBorder(
    //       borderRadius: BorderRadius.circular(16),
    //     ),
    //     title: const Text('Log out'),
    //     content: const Text('Are you sure you want to log out?'),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(context, false),
    //         child: Text(
    //           'Cancel',
    //           style: TextStyle(color: themeColor.primary),
    //         ),
    //       ),
    //       TextButton(
    //         onPressed: () => Navigator.pop(context, true),
    //         child: const Text(
    //           'Log out',
    //           style: TextStyle(color: Colors.red),
    //         ),
    //       ),
    //     ],
    //   ),
    // );

    if (shouldLogout != true || !mounted) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    final name = _user?['name'] as String?;
    final phone = _user?['phone'] as String?;
    final username = _user?['username'] as String?;
    final pic = _user?['profile_pic'] as String?;
    final role = _user?['role'] as String?;
    final createdAt = _user?['created_at'] as String?;
    final callAccess = _user?['call_access'] as bool?;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: const AmigoAppBar(title: 'Account', showBackButton: true),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: themeColor.primary))
          : ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                const SizedBox(height: 8),
                // Avatar header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _openEditProfile,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: themeColor.primaryLight
                                  .withOpacity(0.4),
                              backgroundImage: (pic != null && pic.isNotEmpty)
                                  ? CachedNetworkImageProvider(pic)
                                  : null,
                              child: (pic == null || pic.isEmpty)
                                  ? Text(
                                      _initials(name),
                                      style: TextStyle(
                                        color: themeColor.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 28,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: themeColor.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name ?? '—',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (username != null && username.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: _openEditProfile,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: themeColor.primary,
                        ),
                        label: Text(
                          'Edit profile',
                          style: TextStyle(
                            color: themeColor.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          backgroundColor: themeColor.primary.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ),
                ),
                SettingsSectionHeader(
                  title: 'Your info',
                  color: themeColor.primary,
                ),
                SettingsCard(
                  children: [
                    SettingsValueRow(label: 'Phone', value: phone ?? '—'),
                    SettingsValueRow(
                      label: 'User role',
                      value: (role ?? '—').toUpperCase(),
                      valueColor: themeColor.primary,
                    ),
                    SettingsValueRow(
                      label: 'Account created',
                      value: _formatDate(createdAt),
                    ),
                    SettingsValueRow(
                      label: 'Call access',
                      value: callAccess == true ? 'Enabled' : 'Disabled',
                      valueColor: callAccess == true
                          ? Colors.green[700]
                          : Colors.orange[800],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsCard(
                  children: [
                    SettingsTile(
                      icon: Icons.logout_rounded,
                      iconBackgroundColor: Colors.red.shade400,
                      title: 'Log Out',
                      titleColor: Colors.red,
                      onTap: _logout,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
