import 'package:flutter/material.dart';

/// Small centered pill used while the conversation is catching up with the
/// server — shared between DM and Group messaging screens.
class SyncProgressPill extends StatelessWidget {
  const SyncProgressPill({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ChatPill(label: 'Syncing...');
  }
}

/// Pill shown while loading older pages to find a reply/jump target.
class LoadingTargetPill extends StatelessWidget {
  const LoadingTargetPill({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ChatPill(label: 'Loading message...');
  }
}

class _ChatPill extends StatelessWidget {
  const _ChatPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
