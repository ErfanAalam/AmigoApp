import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart' as m;
import 'package:flutter/foundation.dart';
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
        backgroundColor: backgroundColor ?? Colors.blue[700],
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

/// Long-lived status snackbar for async tasks (loading -> success/failure).
///
/// API:
///   final id = TaskSnack.show(message: 'Uploading...');
///   TaskSnack.resolve(id: id, isSuccess: true, message: 'Done'); // or false
///   TaskSnack.resolve(isSuccess: false); // resolve all as failure
///
/// Notes:
/// - A `show` call returns an id so multiple task snackbars can stack.
/// - While loading, it stays visible and cannot be swiped away.
/// - Resolution triggers success/failure visuals and auto-dismiss.
class TaskSnack {
  static final Map<String, _TaskEntry> _entries = {};
  static int _counter = 0;

  /// Show a loading task snackbar. Returns the id used for stacking/updates.
  static String show({
    required String message,
    String? id,
    Duration successDuration = const Duration(seconds: 2),
    Duration failureDuration = const Duration(seconds: 3),
  }) {
    final overlay = NavigationHelper.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[TaskSnack] ❌ No overlay available');
      return '';
    }

    final entryId = id ?? 'task-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

    // If it already exists, just update the message and keep loading
    final existing = _entries[entryId];
    if (existing != null) {
      existing.state?.updateLoading(message: message);
      return entryId;
    }

    final orderNotifier = ValueNotifier<int>(_entries.length);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TaskSnackOverlay(
        id: entryId,
        message: message,
        successDuration: successDuration,
        failureDuration: failureDuration,
        orderListenable: orderNotifier,
        onRemoved: () => _handleRemoved(entryId),
        registerState: (state) => _entries[entryId]?.state = state,
      ),
    );

    _entries[entryId] = _TaskEntry(
      id: entryId,
      entry: entry,
      orderNotifier: orderNotifier,
    );

    overlay.insert(entry);
    _updateOrders();
    return entryId;
  }

  /// Resolve one (or all) snackbars into success/failure, triggering auto hide.
  static void resolve({
    String? id,
    required bool isSuccess,
    String? message,
  }) {
    if (id != null) {
      _entries[id]?.state?.resolve(isSuccess: isSuccess, message: message);
      return;
    }

    // No id -> resolve all
    for (final entry in _entries.values) {
      entry.state?.resolve(isSuccess: isSuccess, message: message);
    }
  }

  /// Force hide one or all snackbars immediately (no success/failure change).
  static void dismiss({String? id}) {
    if (id != null) {
      _entries[id]?.state?.forceDismiss();
      return;
    }

    for (final entry in _entries.values) {
      entry.state?.forceDismiss();
    }
  }

  static void _handleRemoved(String id) {
    final removed = _entries.remove(id);
    removed?.entry.remove();
    removed?.orderNotifier.dispose();
    _updateOrders();
  }

  static void _updateOrders() {
    var idx = 0;
    for (final entryId in _entries.keys) {
      _entries[entryId]?.orderNotifier.value = idx++;
    }
  }
}

class _TaskEntry {
  final String id;
  final OverlayEntry entry;
  final ValueNotifier<int> orderNotifier;
  _TaskSnackOverlayState? state;

  _TaskEntry({
    required this.id,
    required this.entry,
    required this.orderNotifier,
  });
}

class _TaskSnackOverlay extends StatefulWidget {
  final String id;
  final String message;
  final Duration successDuration;
  final Duration failureDuration;
  final ValueListenable<int> orderListenable;
  final VoidCallback onRemoved;
  final void Function(_TaskSnackOverlayState state) registerState;

  const _TaskSnackOverlay({
    required this.id,
    required this.message,
    required this.successDuration,
    required this.failureDuration,
    required this.orderListenable,
    required this.onRemoved,
    required this.registerState,
  });

  @override
  State<_TaskSnackOverlay> createState() => _TaskSnackOverlayState();
}

class _TaskSnackOverlayState extends State<_TaskSnackOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late String _message;
  bool _isLoading = true;
  bool? _isSuccess;
  late Duration _successDuration;
  late Duration _failureDuration;

  Timer? _autoDismissTimer;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    widget.registerState(this);

    _message = widget.message;
    _successDuration = widget.successDuration;
    _failureDuration = widget.failureDuration;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
    _scheduleAutoDismissIfNeeded();
  }

  void updateLoading({required String message}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _isLoading = true;
      _isSuccess = null;
    });
    _scheduleAutoDismissIfNeeded();
  }

  void resolve({required bool isSuccess, String? message}) {
    if (!mounted) return;

    setState(() {
      _message = message ?? _message;
      _isLoading = false;
      _isSuccess = isSuccess;
    });

    _scheduleAutoDismissIfNeeded();
  }

  void _scheduleAutoDismissIfNeeded() {
    _autoDismissTimer?.cancel();
    if (_isLoading) return; // stay up until task resolves

    final wait = (_isSuccess ?? false) ? _successDuration : _failureDuration;
    _autoDismissTimer = Timer(wait, _animateOut);
  }

  Future<void> _animateOut() async {
    if (_isAnimatingOut || !mounted) return;
    _isAnimatingOut = true;
    await _controller.reverse();
    widget.onRemoved();
  }

  void forceDismiss() {
    _autoDismissTimer?.cancel();
    _animateOut();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color get _tone {
    if (_isLoading) return Colors.blue[700];
    return (_isSuccess ?? false) ? Colors.green[600] : Colors.red[600];
  }

  Widget _buildLeading() {
    if (_isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: m.CircularProgressIndicator(
          strokeWidth: 2.5,
          color: _tone,
        ),
      );
    }

    return Icon(
      (_isSuccess ?? false)
          ? m.Icons.check_circle_rounded
          : m.Icons.error_rounded,
      color: _tone,
      size: 22,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<int>(
      valueListenable: widget.orderListenable,
      builder: (context, order, _) {
        final double itemHeight = 74;
        final double gap = 12;
        final double bottom =
            bottomPadding + 80 + (order * (itemHeight + gap));

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          left: 10,
          right: 10,
          bottom: bottom,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
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
                      color: _tone.withAlpha(150).withLuminance(0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _tone.withAlpha(150),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildLeading(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _tone,
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
        );
      },
    );
  }
}
