import 'package:flutter/material.dart';

/// A small green dot that pulses (opacity + subtle scale) to draw attention.
/// Used to flag a rejoinable (still-active) call on its Call-Logs row and over
/// the Calls tab in the bottom navbar.
///
/// Owns its own [AnimationController] and disposes it in [dispose], so it
/// cleans up automatically the moment it's removed from the tree (e.g. when the
/// rejoinable-call provider clears and the `Consumer` rebuilds it away).
class PulsingDot extends StatefulWidget {
  final double size;
  final Color color;

  const PulsingDot({
    super.key,
    this.size = 10,
    this.color = const Color(0xFF22C55E),
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Eased 0..1 pulse value.
        final t = Curves.easeInOut.transform(_controller.value);
        final opacity = 0.55 + 0.45 * t;
        final scale = 0.85 + 0.15 * t;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.55 * t),
                    blurRadius: 6 * t,
                    spreadRadius: 1.5 * t,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
