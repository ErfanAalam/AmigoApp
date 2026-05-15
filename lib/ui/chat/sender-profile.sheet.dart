import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// WhatsApp-style profile bottom sheet shown on tapping a sender's name in a
/// group bubble. Shows pfp + name + Message / Audio / Video actions. No phone
/// number, no Info / Pay / Verify rows.
class SenderProfileSheet extends StatelessWidget {
  final String? profilePic;
  final String displayName;
  final VoidCallback onMessage;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;
  final bool showCallActions;

  const SenderProfileSheet({
    super.key,
    required this.profilePic,
    required this.displayName,
    required this.onMessage,
    required this.onAudioCall,
    required this.onVideoCall,
    this.showCallActions = true,
  });

  static Future<void> show({
    required BuildContext context,
    required String? profilePic,
    required String displayName,
    required VoidCallback onMessage,
    required VoidCallback onAudioCall,
    required VoidCallback onVideoCall,
    bool showCallActions = true,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SenderProfileSheet(
        profilePic: profilePic,
        displayName: displayName,
        onMessage: onMessage,
        onAudioCall: onAudioCall,
        onVideoCall: onVideoCall,
        showCallActions: showCallActions,
      ),
    );
  }

  String _initial() {
    final t = displayName.trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            _buildAvatar(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                displayName.isEmpty ? 'Unknown User' : displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActionRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    const size = 120.0;
    if (profilePic != null && profilePic!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profilePic!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _fallbackAvatar(size),
          errorWidget: (_, __, ___) => _fallbackAvatar(size),
        ),
      );
    }
    return _fallbackAvatar(size);
  }

  Widget _fallbackAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.teal[100],
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initial(),
        style: TextStyle(
          color: Colors.teal[700],
          fontSize: 56,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    final children = <Widget>[
      Expanded(
        child: _ActionTile(
          icon: Icons.message_outlined,
          label: 'Message',
          onTap: onMessage,
        ),
      ),
      if (showCallActions) ...[
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.call_outlined,
            label: 'Audio',
            onTap: onAudioCall,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.videocam_outlined,
            label: 'Video',
            onTap: onVideoCall,
          ),
        ),
      ],
    ];
    return Row(children: children);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withOpacity(0.12)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black87, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
