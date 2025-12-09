import 'package:flutter/material.dart';

/// Reusable animated dots loading indicator
class LoadingDotsAnimation extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double spacing;
  final String? message;
  final TextStyle? messageStyle;

  const LoadingDotsAnimation({
    super.key,
    this.color,
    this.dotSize = 6,
    this.spacing = 2,
    this.message,
    this.messageStyle,
  });

  @override
  State<LoadingDotsAnimation> createState() => _LoadingDotsAnimationState();
}

class _LoadingDotsAnimationState extends State<LoadingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    // Start the animation and repeat it
    _animationController.forward();
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final animationValue = (_animation.value - delay).clamp(
                  0.0,
                  1.0,
                );
                final opacity = (1.0 - (animationValue - 0.5).abs() * 2).clamp(
                  0.0,
                  1.0,
                );

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: widget.spacing),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: widget.dotSize,
                      height: widget.dotSize,
                      decoration: BoxDecoration(
                        color: widget.color ?? Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.message!,
            style:
                widget.messageStyle ??
                TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ],
    );
  }
}
