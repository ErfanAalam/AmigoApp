import 'package:flutter/material.dart';

/// Custom page route that slides in from the right with smooth animation
class SlideRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideRightRoute({required this.page})
    : super(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => page,
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              // Slide in from right with smooth curve
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              // Using fastOutSlowIn for buttery smooth animation
              const curve = Curves.fastOutSlowIn;

              // Slide animation
              final slideTween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));

              // Fade animation for extra smoothness
              final fadeTween = Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(slideTween),
                child: FadeTransition(
                  opacity: animation.drive(fadeTween),
                  child: child,
                ),
              );
            },
        // Increased duration for smoother animation
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
      );
}
