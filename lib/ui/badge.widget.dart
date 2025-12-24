import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme-color.provider.dart';

/// A WhatsApp-style notification badge widget
///
/// Displays a small circular red badge with white text.
/// Auto-hides when count is zero.
/// Handles double-digit numbers gracefully (max "99+").
class BadgeWidget extends ConsumerWidget {
  final int count;
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;
  final double? fontSize;
  final EdgeInsets? padding;

  const BadgeWidget({
    super.key,
    required this.count,
    required this.child,
    this.badgeColor,
    this.textColor,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    // Don't show badge if count is zero
    if (count <= 0) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding:
                padding ??
                EdgeInsets.symmetric(
                  horizontal: _formatCount(count).length <= 2 ? 5 : 7,
                  vertical: 1,
                ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: badgeColor ?? themeColor.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _formatCount(count),
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: fontSize ?? (count > 99 ? 9 : 11),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// Format count to show "99+" for numbers greater than 99
  String _formatCount(int count) {
    if (count > 99) {
      return '99+';
    }
    return count.toString();
  }
}
