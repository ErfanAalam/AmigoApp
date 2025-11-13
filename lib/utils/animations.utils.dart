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
