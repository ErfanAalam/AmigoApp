import 'package:flutter/material.dart';

import '../../../models/message.model.dart';

/// Swipe-to-reply gesture handling shared by DM and group messaging screens.
///
/// Owns animation controllers, gesture-classification state, and the
/// reply-icon overlay built around an existing message bubble. The host
/// state class supplies the selected-message set (used to suppress the
/// gesture during multi-select) and the `onSwipeReply` callback that is
/// fired once the swipe completes.
///
/// `isScrolling` is intentionally part of this mixin even though scroll
/// parts also write to it — gesture classification needs to gate on
/// "scroll started" to abort an in-flight swipe.
mixin ChatSwipeReplyMixin<T extends StatefulWidget>
    on State<T>, TickerProvider {
  static const double _minSwipeDistanceSq = 0; // 4px²
  static const double _maxSwipeAngleRatio = 0.18; // ~10° off horizontal
  static const double _minSwipeVelocity = 500.0;
  static const double _swipeThreshold = 0.6;

  final Map<String, AnimationController> swipeAnimationControllers = {};
  final Map<String, Animation<double>> swipeAnimations = {};

  Offset? swipeStartPosition;
  bool isSwipeGesture = false;
  bool isScrolling = false;

  Set<String> get selectedMessageIds;
  void onSwipeReply(MessageModel message);

  void onSwipeStart(MessageModel message, DragStartDetails details) {
    if (!swipeAnimationControllers.containsKey(message.id)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );
      swipeAnimationControllers[message.id] = controller;
      swipeAnimations[message.id] = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }

    swipeStartPosition = details.globalPosition;
    isSwipeGesture = false;
  }

  void onSwipeUpdate(
    MessageModel message,
    DragUpdateDetails details,
    bool isMyMessage,
  ) {
    if (selectedMessageIds.isNotEmpty ||
        swipeStartPosition == null ||
        isScrolling) {
      return;
    }

    final currentPosition = details.globalPosition;
    final dx = currentPosition.dx - swipeStartPosition!.dx;
    final dy = (currentPosition.dy - swipeStartPosition!.dy).abs();

    if (!isSwipeGesture) {
      final distSq = dx * dx + dy * dy;
      if (distSq < _minSwipeDistanceSq) {
        return;
      }
      if (dx > 0 && dy < dx * _maxSwipeAngleRatio) {
        isSwipeGesture = true;
      } else {
        isScrolling = true;
        return;
      }
    }

    if (dx > 0) {
      final controller = swipeAnimationControllers[message.id];
      if (controller != null) {
        controller.value = (dx / 100).clamp(0.0, 1.0);
      }
    }
  }

  void onSwipeEnd(
    MessageModel message,
    DragEndDetails details,
    bool isMyMessage,
  ) {
    final controller = swipeAnimationControllers[message.id];
    if (controller != null) {
      if (isSwipeGesture &&
          (details.velocity.pixelsPerSecond.dx > _minSwipeVelocity ||
              controller.value > _swipeThreshold)) {
        controller.forward().then((_) {
          onSwipeReply(message);
          controller.reverse();
        });
      } else {
        controller.reverse();
      }
    }

    swipeStartPosition = null;
    isSwipeGesture = false;
    isScrolling = false;
  }

  /// Wraps an already-built message bubble with the swipe-reply overlay.
  /// `bubbleBuilder` is invoked on every animation frame to preserve the
  /// pre-extraction behavior — pass a stable widget if you want to opt
  /// into the AnimatedBuilder `child:` perf path instead.
  Widget buildSwipeableMessageBubble({
    required MessageModel message,
    required bool isMyMessage,
    required Color replyIconBackgroundColor,
    required Widget Function() bubbleBuilder,
  }) {
    final swipeAnimation = swipeAnimations[message.id];

    if (swipeAnimation != null) {
      return AnimatedBuilder(
        animation: swipeAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              if (swipeAnimation.value > 0.1)
                Positioned(
                  left: isMyMessage ? 16 : null,
                  right: isMyMessage ? null : 16,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: swipeAnimation.value,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: replyIconBackgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.reply,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(swipeAnimation.value * 50, 0),
                child: bubbleBuilder(),
              ),
            ],
          );
        },
      );
    }

    return bubbleBuilder();
  }

  void disposeSwipeReply() {
    for (final controller in swipeAnimationControllers.values) {
      controller.dispose();
    }
    swipeAnimationControllers.clear();
    swipeAnimations.clear();
  }
}
