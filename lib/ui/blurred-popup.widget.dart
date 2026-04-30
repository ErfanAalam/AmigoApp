import 'dart:ui';

import 'package:flutter/material.dart';

/// Visual style for a [BlurredPopupAction]:
///
/// * [normal] — default body text, neutral icon.
/// * [destructive] — red text + icon, for irreversible actions
///   (Delete, Remove, Leave, …).
/// * [ghost] — muted/secondary appearance, useful for tertiary
///   actions you want to deemphasise without removing entirely.
enum BlurredPopupActionStyle { normal, destructive, ghost }

/// One entry inside a [showBlurredPopup] menu. Either an [BlurredPopupAction]
/// (selectable row) or a [BlurredPopupSeparator] (thin divider).
sealed class BlurredPopupItem {
  const BlurredPopupItem();
}

/// A tappable row. The popup pops with [value] when this row is selected,
/// so callers can `await showBlurredPopup<T>(…)` and switch on the result.
class BlurredPopupAction<T> extends BlurredPopupItem {
  final String label;
  final IconData? icon;
  final T value;
  final BlurredPopupActionStyle style;
  final bool enabled;

  const BlurredPopupAction({
    required this.label,
    required this.value,
    this.icon,
    this.style = BlurredPopupActionStyle.normal,
    this.enabled = true,
  });
}

/// A thin horizontal divider between items. Indents past the icon column so
/// rows visually align — same convention as iOS/macOS context menus.
class BlurredPopupSeparator extends BlurredPopupItem {
  const BlurredPopupSeparator();
}

/// Show an anchored popup that grows from [position] (typically the trigger
/// button's bounds, or a tap-down position). Returns the [value] of the
/// selected [BlurredPopupAction], or `null` if the user dismissed it.
///
/// The popup itself paints an 80% white surface over a `BackdropFilter` so
/// whatever's behind it gets a frosted-glass blur — the area *outside* the
/// popup stays unblurred.
///
/// [scaleAlignment] controls where the open/close scale animation
/// originates from. The default works well for app-bar trigger buttons
/// (top-right of the screen); pass [Alignment.topLeft] when triggering
/// from a left-side anchor or a tap-down at the user's finger.
Future<T?> showBlurredPopup<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<BlurredPopupItem> items,
  double minWidth = 200,
  double maxWidth = 280,
  Alignment scaleAlignment = Alignment.topRight,
  bool barrierDismissible = true,
}) {
  return Navigator.of(context).push(
    _BlurredPopupRoute<T>(
      position: position,
      items: items,
      minWidth: minWidth,
      maxWidth: maxWidth,
      scaleAlignment: scaleAlignment,
      barrierDismissible: barrierDismissible,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context).context,
      ),
    ),
  );
}

/// Convenience widget for the most common case: an icon button that, on
/// press, opens a [showBlurredPopup] anchored to itself. Dispatches the
/// selected value through [onSelected]. Typed on `T` so the menu can
/// return any sentinel you like (enums, strings, …).
class BlurredPopupButton<T> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final EdgeInsets padding;
  final String? tooltip;
  final List<BlurredPopupItem> Function() itemsBuilder;
  final ValueChanged<T> onSelected;
  final double menuMinWidth;
  final double menuMaxWidth;
  final Alignment scaleAlignment;

  const BlurredPopupButton({
    super.key,
    required this.icon,
    required this.itemsBuilder,
    required this.onSelected,
    this.iconColor = Colors.white,
    this.iconSize = 24,
    this.padding = const EdgeInsets.all(8),
    this.tooltip,
    this.menuMinWidth = 180,
    this.menuMaxWidth = 280,
    this.scaleAlignment = Alignment.topRight,
  });

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlayBox),
        box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlayBox,
        ),
      ),
      Offset.zero & overlayBox.size,
    );

    final result = await showBlurredPopup<T>(
      context: context,
      position: position,
      items: itemsBuilder(),
      minWidth: menuMinWidth,
      maxWidth: menuMaxWidth,
      scaleAlignment: scaleAlignment,
    );
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      icon: Icon(icon, color: iconColor, size: iconSize),
      tooltip: tooltip,
      padding: padding,
      onPressed: () => _open(context),
    );
    return btn;
  }
}

// ─── Internals ─────────────────────────────────────────────────────────────

const double _kRadius = 18.0;
const double _kBlurSigma = 24.0;
const Color _kPopupSurface = Color(0xCCFFFFFF); // ~80% white

class _BlurredPopupRoute<T> extends PopupRoute<T> {
  final RelativeRect position;
  final List<BlurredPopupItem> items;
  final double minWidth;
  final double maxWidth;
  final Alignment scaleAlignment;
  final bool _barrierDismissible;
  final CapturedThemes capturedThemes;

  _BlurredPopupRoute({
    required this.position,
    required this.items,
    required this.minWidth,
    required this.maxWidth,
    required this.scaleAlignment,
    required bool barrierDismissible,
    required this.capturedThemes,
  }) : _barrierDismissible = barrierDismissible;

  @override
  Color? get barrierColor => null; // outside popup stays untouched

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 140);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SafeArea(
      child: CustomSingleChildLayout(
        delegate: _PopupLayoutDelegate(position: position),
        child: capturedThemes.wrap(
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
            // Pass the route animation down so the surface can drive its
            // blur / tint / shadow alphas itself. We deliberately do NOT
            // wrap the popup in a FadeTransition: that creates an
            // `OpacityLayer` above the `BackdropFilter`, and the filter
            // can't sample its parent layer through one — you get the
            // "blur snaps in a frame after the surface" glitch.
            child: _PopupSurface(items: items, animation: animation),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Scale only — fade is composited inside the surface (see above).
    // ScaleTransition uses Transform under the hood, which doesn't create
    // an opacity layer, so the BackdropFilter stays happy.
    final t = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    final scale = Tween<double>(begin: 0.94, end: 1.0).animate(t);
    return ScaleTransition(
      alignment: scaleAlignment,
      scale: scale,
      child: child,
    );
  }
}

/// Positions the popup near [position] (typically the trigger button's
/// bounds), preferring just below the anchor right-aligned to its right
/// edge. Flips above when there's no room below; clamps to a small inset
/// on every edge so the popup never sticks to a screen border.
class _PopupLayoutDelegate extends SingleChildLayoutDelegate {
  static const double _spacing = 6;
  static const double _screenPadding = 8;

  final RelativeRect position;

  const _PopupLayoutDelegate({required this.position});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        constraints.maxWidth - _screenPadding * 2,
        constraints.maxHeight - _screenPadding * 2,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchorBottom = size.height - position.bottom;
    final anchorRight = size.width - position.right;

    // Default: place the popup below, with its right edge aligned to the
    // anchor's right edge. Mirrors the natural "menu drops down from
    // the trigger" motion most users already expect.
    double y = anchorBottom + _spacing;
    double x = anchorRight - childSize.width;

    // Vertical: flip above when there's no room below.
    if (y + childSize.height > size.height - _screenPadding) {
      final above = position.top - _spacing - childSize.height;
      y = above >= _screenPadding
          ? above
          : size.height - _screenPadding - childSize.height;
    }
    if (y < _screenPadding) y = _screenPadding;

    // Horizontal clamp to keep within the screen.
    if (x < _screenPadding) x = _screenPadding;
    if (x + childSize.width > size.width - _screenPadding) {
      x = size.width - _screenPadding - childSize.width;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _PopupLayoutDelegate old) =>
      position != old.position;
}

class _PopupSurface extends StatelessWidget {
  final List<BlurredPopupItem> items;
  final Animation<double> animation;

  const _PopupSurface({required this.items, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Match the entrance/exit curve used by the route's ScaleTransition
        // so the surface materialises in lockstep with the scale, no
        // perceptible "blur appears one frame late" seam.
        final t = Curves.easeOutCubic.transform(
          animation.value.clamp(0.0, 1.0),
        );
        return Material(
          type: MaterialType.transparency,
          // Shadow lives on the outer container so it paints behind the
          // ClipRRect — putting it inside the clip would mask the soft
          // outer halo. Its alpha rides `t` so the shadow grows in along
          // with the popup instead of popping in fully formed.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08 * t),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04 * t),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kRadius),
              // Sigma scales 0 → _kBlurSigma so the blur ramps up smoothly
              // alongside the surface tint. Animating sigma instead of
              // wrapping in Opacity keeps the BackdropFilter out of an
              // OpacityLayer, which is what was causing the visible seam.
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _kBlurSigma * t,
                  sigmaY: _kBlurSigma * t,
                ),
                // Items + tint share one Opacity layer *inside* the
                // BackdropFilter — safe, because the filter has already
                // sampled its parent layer by the time this layer composes.
                child: Opacity(
                  opacity: t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _kPopupSurface,
                      borderRadius: BorderRadius.circular(_kRadius),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in items) _renderItem(context, item),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _renderItem(BuildContext context, BlurredPopupItem item) {
    return switch (item) {
      BlurredPopupSeparator() => const _Separator(),
      BlurredPopupAction() => _ActionTile(action: item),
    };
  }
}

class _ActionTile<T> extends StatefulWidget {
  final BlurredPopupAction<T> action;

  const _ActionTile({required this.action});

  @override
  State<_ActionTile<T>> createState() => _ActionTileState<T>();
}

class _ActionTileState<T> extends State<_ActionTile<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final color = switch (action.style) {
      BlurredPopupActionStyle.destructive => const Color(0xFFD32F2F),
      BlurredPopupActionStyle.ghost => const Color(0xFF8A8F98),
      BlurredPopupActionStyle.normal => const Color(0xFF1F2329),
    };
    final disabledColor = color.withValues(alpha: 0.35);
    final enabled = action.enabled;
    final fg = enabled ? color : disabledColor;

    // Press fill = 5% of the row's text color. Same border radius as the
    // popup itself so the fill on the corner rows tucks neatly against the
    // outer clip; middle rows show as flat strips, which is the intent.
    final pressBg = color.withValues(alpha: 0.05);

    void setPressed(bool v) {
      if (!enabled) return;
      if (_pressed != v) setState(() => _pressed = v);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setPressed(true),
      onTapCancel: () => setPressed(false),
      onTap: enabled
          ? () {
              setPressed(false);
              Navigator.of(context).pop(action.value);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _pressed ? pressBg : Colors.transparent,
          borderRadius: BorderRadius.circular(_kRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 19, color: fg),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                action.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      // Faint inner divider — sits well on the frosted surface without
      // visually splitting the popup into separate cards.
      color: Colors.black.withValues(alpha: 0.06),
    );
  }
}
