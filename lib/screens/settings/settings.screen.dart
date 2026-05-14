import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme-color.provider.dart';
import '../../ui/app-bar.widget.dart';
import '../../ui/settings-tile.widget.dart';
import '../../utils/user.utils.dart';
import 'about.screen.dart';
import 'account-settings.screen.dart';
import 'appearance.screen.dart';
import 'chat-settings.screen.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await UserUtils().getUserDetails();
    if (!mounted) return;
    setState(() => _user = u?.toJson());
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    final name = _user?['name'] as String?;
    final phone = _user?['phone'] as String?;
    final pic = _user?['profile_pic'] as String?;
    final username = _user?['username'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: const AmigoAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const SizedBox(height: 8),
          // Profile header card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: themeColor.primaryLight.withOpacity(0.4),
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
                const SizedBox(height: 12),
                Text(
                  name ?? '—',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (phone != null && phone.isNotEmpty) phone,
                    if (username != null && username.isNotEmpty) '@$username',
                  ].join('  •  '),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.person_outline_rounded,
                iconBackgroundColor: const Color(0xFF3B9CFD),
                title: 'Account',
                subtitle: 'Role, member since, call access',
                trailing: _chevron(),
                onTap: () => _open(const AccountSettingsScreen()),
              ),
              SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                iconBackgroundColor: const Color(0xFFFF9F40),
                title: 'Chat Settings',
                subtitle: 'Quick replies, deleted chats',
                trailing: _chevron(),
                onTap: () => _open(const ChatSettingsScreen()),
              ),
              SettingsTile(
                icon: Icons.color_lens_outlined,
                iconBackgroundColor: const Color(0xFF9C66F0),
                title: 'Appearance',
                subtitle: 'Theme color, chat background',
                trailing: _chevron(),
                onTap: () => _open(const AppearanceScreen()),
              ),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                iconBackgroundColor: const Color(0xFF34C759),
                title: 'About',
                subtitle: 'Version, network diagnostics',
                trailing: _chevron(),
                onTap: () => _open(const AboutScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chevron() => Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey[400],
        size: 22,
      );
}
