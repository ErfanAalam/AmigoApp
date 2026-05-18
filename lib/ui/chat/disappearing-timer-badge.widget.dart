import 'package:flutter/material.dart';

/// Small clock badge that overlays the top-right corner of a chat avatar to
/// signal that the chat has disappearing messages enabled. Designed to be
/// dropped into a Stack on top of a CircleAvatar.
///
/// Use [size] to scale for different avatar sizes:
///   • List rows   → size 14
///   • App-bar DPs → size 12
class DisappearingTimerBadge extends StatelessWidget {
  final Color color;
  final double size;
  final Color ringColor;

  const DisappearingTimerBadge({
    super.key,
    required this.color,
    this.size = 20,
    this.ringColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ringColor,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 0.1),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.history_toggle_off_rounded, color: color, size: size),
    );
  }
}
