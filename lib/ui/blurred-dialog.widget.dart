import 'dart:ui';

import 'package:flutter/material.dart';

const double _kRadius = 18.0;
const double _kBlurSigma = 24.0;
const Color _kSurface = Color(0xCCFFFFFF); // ~80% white

/// Show a centered dialog with the same frosted-glass look as
/// [showBlurredPopup]: 80% white surface stacked on a backdrop blur, slight
/// scale-and-fade in/out animation. Returns whatever was passed to
/// `Navigator.pop` from inside the dialog.
///
/// Use [body] for the main content (any widget — a paragraph, a form, a
/// list). Use [footer] when you want full control over the bottom action
/// row; pass `null` to hide a footer entirely. For the very common
/// "Yes / Cancel" pattern, prefer [showBlurredConfirm] which wires the
/// default footer for you.
Future<T?> showBlurredDialog<T>({
  required BuildContext context,
  String? title,
  required Widget body,
  Widget? footer,
  bool barrierDismissible = true,
  EdgeInsets bodyPadding = const EdgeInsets.fromLTRB(20, 4, 20, 8),
  double maxWidth = 360,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => _BlurredDialogShell(
      title: title,
      body: body,
      footer: footer,
      bodyPadding: bodyPadding,
      maxWidth: maxWidth,
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      // Subtle scale — the dialog appears in place rather than rushing
      // toward the user. Pairs with the fade so neither effect dominates.
      final scale = Tween<double>(begin: 0.96, end: 1.0).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

/// "Are you sure?" sugar over [showBlurredDialog]. Resolves to `true` for
/// confirm, `false` for cancel, and `null` if dismissed via the barrier.
/// Set [destructive] to paint the confirm button in red — for irreversible
/// actions like Delete / Leave / Remove.
Future<bool?> showBlurredConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Yes',
  String cancelLabel = 'Cancel',
  IconData? confirmIcon,
  bool destructive = false,
}) {
  return showBlurredDialog<bool>(
    context: context,
    title: title,
    body: Text(
      message,
      style: const TextStyle(
        fontSize: 14,
        height: 1.45,
        color: Color(0xFF3A3F47),
      ),
    ),
    footer: BlurredDialogActions(
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      confirmIcon: confirmIcon,
      destructive: destructive,
      onCancel: (ctx) => Navigator.of(ctx).pop(false),
      onConfirm: (ctx) => Navigator.of(ctx).pop(true),
    ),
  );
}

/// Standard footer row used by [showBlurredConfirm]. Exposed so callers of
/// the generic [showBlurredDialog] can drop in the same button styling
/// alongside fully-custom body content (e.g. a form).
class BlurredDialogActions extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final IconData? confirmIcon;
  final bool destructive;
  final void Function(BuildContext context) onCancel;
  final void Function(BuildContext context) onConfirm;
  final bool confirmEnabled;

  const BlurredDialogActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.confirmLabel = 'Yes',
    this.confirmIcon,
    this.destructive = false,
    this.confirmEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final confirmBg = destructive ? const Color(0xFFD32F2F) : const Color(0xFF1F6FEB);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF3A3F47),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => onCancel(context),
          child: Text(
            cancelLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmBg,
            foregroundColor: Colors.white,
            disabledBackgroundColor: confirmBg.withValues(alpha: 0.45),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: confirmEnabled ? () => onConfirm(context) : null,
          // ElevatedButton.icon needs an icon slot; render an empty box
          // when none is provided so the label hugs the start.
          icon: confirmIcon != null
              ? Icon(confirmIcon, size: 18)
              : const SizedBox.shrink(),
          label: Text(
            confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _BlurredDialogShell extends StatelessWidget {
  final String? title;
  final Widget body;
  final Widget? footer;
  final EdgeInsets bodyPadding;
  final double maxWidth;

  const _BlurredDialogShell({
    required this.title,
    required this.body,
    required this.footer,
    required this.bodyPadding,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _kBlurSigma,
                  sigmaY: _kBlurSigma,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(_kRadius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                          child: Text(
                            title!,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2329),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      Padding(padding: bodyPadding, child: body),
                      if (footer != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: footer,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
