import 'dart:ui';
import 'package:flutter/material.dart';

/// WhatsApp-style floating scroll to bottom button
///
/// Shows when user scrolls up or new messages arrive while not at bottom.
/// Hides automatically when user reaches the bottom.
class ScrollToBottomButton extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onTap;
  final int? unreadCount;
  final bool isAtBottom;
  final double bottomPadding;

  const ScrollToBottomButton({
    super.key,
    required this.scrollController,
    required this.onTap,
    this.unreadCount,
    required this.isAtBottom,
    this.bottomPadding = 0.0,
  });

  @override
  State<ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<ScrollToBottomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _updateVisibility();
  }

  @override
  void didUpdateWidget(ScrollToBottomButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAtBottom != widget.isAtBottom ||
        oldWidget.unreadCount != widget.unreadCount) {
      _updateVisibility();
    }
  }

  void _updateVisibility() {
    final shouldShow = !widget.isAtBottom;
    if (shouldShow != _isVisible) {
      setState(() {
        _isVisible = shouldShow;
      });
      if (shouldShow) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: IgnorePointer(
        ignoring: !_isVisible,
        child: Material(
          elevation: 6,
          shadowColor: Colors.black.withAlpha(30),
          shape: const CircleBorder(),
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(100),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.teal.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.teal[700],
                          size: 28,
                        ),
                      ),
                      // Unread count badge
                      if (widget.unreadCount != null && widget.unreadCount! > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              widget.unreadCount! > 99
                                  ? '99+'
                                  : widget.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
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
