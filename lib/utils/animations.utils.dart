import 'package:flutter/material.dart';

/// Initializes typing dot animations for chat screens.
/// Returns a tuple containing the animation controller and the list of dot animations.
({AnimationController controller, List<Animation<double>> dotAnimations})
initializeTypingDotAnimation(TickerProvider vsync) {
  final controller = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: vsync,
  );

  // Create simple staggered animations for each dot with safe intervals
  final dotAnimations = [
    // Dot 0: 0.0 to 0.5
    Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    ),
    // Dot 1: 0.2 to 0.7
    Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
      ),
    ),
    // Dot 2: 0.4 to 0.9
    Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeInOut),
      ),
    ),
  ];

  return (controller: controller, dotAnimations: dotAnimations);
}

/// Initializes voice recording animations for chat screens.
/// Returns a tuple containing the voice modal animation controller, zigzag animation controller,
/// voice modal animation, and zigzag animation.
({
  AnimationController voiceModalController,
  AnimationController zigzagController,
  Animation<double> voiceModalAnimation,
  Animation<double> zigzagAnimation,
})
initializeVoiceAnimations(TickerProvider vsync) {
  final voiceModalController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: vsync,
  );

  final zigzagController = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: vsync,
  );

  final voiceModalAnimation = CurvedAnimation(
    parent: voiceModalController,
    curve: Curves.easeOutBack,
  );

  final zigzagAnimation = Tween<double>(
    begin: 0.3,
    end: 1.0,
  ).animate(CurvedAnimation(parent: zigzagController, curve: Curves.easeInOut));

  return (
    voiceModalController: voiceModalController,
    zigzagController: zigzagController,
    voiceModalAnimation: voiceModalAnimation,
    zigzagAnimation: zigzagAnimation,
  );
}

/// Builds a typing animation widget with three animated dots.
/// Takes a list of animations for the three dots.
Widget buildTypingAnimation(List<Animation<double>> dotAnimations) {
  return SizedBox(
    width: 24,
    height: 12,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTypingDot(0, dotAnimations),
        _buildTypingDot(1, dotAnimations),
        _buildTypingDot(2, dotAnimations),
      ],
    ),
  );
}

// ─── Reusable Staggered Animation Wrappers ──────────────────────────────────

/// Staggered fade+scale entrance animation for grid tiles.
/// Wraps any child widget with a smooth scale-up + fade-in effect,
/// staggered by [index] (40ms per item, capped at 600ms).
class StaggeredScaleFadeTile extends StatefulWidget {
  final int index;
  final Widget child;
  final int staggerDelayMs;
  final int maxDelayMs;

  const StaggeredScaleFadeTile({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelayMs = 50,
    this.maxDelayMs = 600,
  });

  @override
  State<StaggeredScaleFadeTile> createState() => _StaggeredScaleFadeTileState();
}

class _StaggeredScaleFadeTileState extends State<StaggeredScaleFadeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    final delay = (widget.index * widget.staggerDelayMs).clamp(
      0,
      widget.maxDelayMs,
    );
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}

/// Staggered fade+slide entrance animation for list items.
/// Wraps any child widget with a smooth slide-up + fade-in effect,
/// staggered by [index] (55ms per item, capped at 600ms).
class StaggeredSlideFadeItem extends StatefulWidget {
  final int index;
  final Widget child;
  final int staggerDelayMs;
  final int maxDelayMs;

  const StaggeredSlideFadeItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelayMs = 55,
    this.maxDelayMs = 600,
  });

  @override
  State<StaggeredSlideFadeItem> createState() => _StaggeredSlideFadeItemState();
}

class _StaggeredSlideFadeItemState extends State<StaggeredSlideFadeItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    final delay = (widget.index * widget.staggerDelayMs).clamp(
      0,
      widget.maxDelayMs,
    );
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}

/// Builds a single typing dot with animation.
Widget _buildTypingDot(int index, List<Animation<double>> dotAnimations) {
  return AnimatedBuilder(
    animation: dotAnimations[index],
    builder: (context, child) {
      return Transform.translate(
        offset: Offset(0, dotAnimations[index].value * -4),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[500],
            shape: BoxShape.circle,
          ),
        ),
      );
    },
  );
}
