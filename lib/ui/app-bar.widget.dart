import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme-color.provider.dart';

/// Reusable AppBar matching the DM list style: white background,
/// themed-color title, minimal leading, theme-color action icons.
class AmigoAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double leadingWidth;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AmigoAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.leadingWidth = 2,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);

    Widget? effectiveLeading = leading;
    double effectiveLeadingWidth = leadingWidth;
    if (showBackButton && leading == null) {
      effectiveLeading = IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: themeColor.primary,
          size: 20,
        ),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      );
      effectiveLeadingWidth = 48;
    }

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: effectiveLeadingWidth,
      leading: effectiveLeading,
      title: Text(
        title,
        style: TextStyle(
          color: themeColor.primary,
          fontWeight: FontWeight.bold,
          fontSize: 25,
          letterSpacing: 0.2,
        ),
      ),
      actions: actions,
    );
  }
}

/// Standard icon-only action button used in the new app bar.
class AmigoAppBarAction extends ConsumerWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final EdgeInsetsGeometry margin;

  const AmigoAppBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 20,
    this.margin = const EdgeInsets.only(right: 6),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    return Container(
      margin: margin,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: themeColor.primary,
          opticalSize: 300,
          size: size,
        ),
      ),
    );
  }
}
