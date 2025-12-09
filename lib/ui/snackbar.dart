import 'dart:ui';
// import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/navigation-helper.util.dart';

/// Simple overlay-based snackbar - no scaffold context needed!
///
/// Usage:
///   Snack.show('Hello world');
///   Snack.show('Success!', backgroundColor: Colors.green);
///   Snack.show('Error!', backgroundColor: Colors.red, duration: Duration(seconds: 5));
class Snack {
  static OverlayEntry? _currentEntry;

  /// Show a blurred snackbar
  static void show(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Get overlay from navigator
    final overlay = NavigationHelper.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[Snack] ❌ No overlay available');
      return;
    }

    // Remove existing snackbar if any
    _dismiss();

    _currentEntry = OverlayEntry(
      builder: (context) => _SnackOverlay(
        message: message,
        backgroundColor: backgroundColor ?? Colors.blue[700]!,
        duration: duration,
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_currentEntry!);
  }

  /// Show success snackbar (green)
  static void success(String message, {Duration? duration}) {
    show(
      message,
      backgroundColor: Colors.green[600],
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Show error snackbar (red)
  static void error(String message, {Duration? duration}) {
    show(
      message,
      backgroundColor: Colors.red[600],
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Show warning snackbar (orange)
  static void warning(String message, {Duration? duration}) {
    show(
      message,
      backgroundColor: Colors.orange[700],
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Dismiss current snackbar
  static void _dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _SnackOverlay extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SnackOverlay({
    required this.message,
    required this.backgroundColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_SnackOverlay> createState() => _SnackOverlayState();
}

class _SnackOverlayState extends State<_SnackOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _animateOut();
      }
    });
  }

  void _animateOut() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 10,
      right: 10,
      bottom: bottomPadding + 80,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              // Swipe down to dismiss
              if (details.velocity.pixelsPerSecond.dy > 100) {
                _animateOut();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor
                        .withAlpha(150)
                        .withLuminance(0.96),
                    // color: Colors.white.withAlpha(150),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.backgroundColor.withAlpha(150),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.backgroundColor,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
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
