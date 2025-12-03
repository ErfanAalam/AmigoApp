import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/call.provider.dart';
import '../models/call_model.dart';

/// Wraps an AppBar (or any PreferredSizeWidget) and adjusts its height
/// smoothly when the call bar appears, accounting for notch/punch hole phones.
/// 
/// The GlobalCallBar uses SafeArea which adds padding for the notch.
/// When it appears, this widget reduces the AppBar's effective height
/// by the call bar height to prevent extra spacing.
/// 
/// Usage:
/// ```dart
/// appBar: AdaptiveAppBar(
///   appBar: AppBar(
///     title: Text('My Screen'),
///   ),
/// ),
/// ```
class AdaptiveAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final PreferredSizeWidget appBar;
  final double callBarHeight;

  const AdaptiveAppBar({
    super.key,
    required this.appBar,
    this.callBarHeight = 56.0, // Height of GlobalCallBar (without SafeArea)
  });

  @override
  ConsumerState<AdaptiveAppBar> createState() => _AdaptiveAppBarState();

  @override
  Size get preferredSize {
    // Return dynamic size - will be adjusted in build method
    return appBar.preferredSize;
  }
}

class _AdaptiveAppBarState extends ConsumerState<AdaptiveAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _heightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callServiceState = ref.watch(callServiceProvider);
    final activeCall = callServiceState.activeCall;

    // Check if we're on the call screen
    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);
    final bool isOnCallScreen = currentRoute?.settings.name == '/call';

    // Check if call bar should be visible (answered call and not on call screen)
    final bool shouldShowCallBar = activeCall != null &&
        activeCall.status == CallStatus.answered &&
        !isOnCallScreen;

    // Animate height adjustment smoothly
    if (shouldShowCallBar) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    // Calculate the height adjustment
    // When call bar is visible, reduce AppBar height by call bar height
    // This prevents double spacing since GlobalCallBar already handles SafeArea
    final double heightAdjustment = _heightAnimation.value * widget.callBarHeight;

    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        return PreferredSize(
          preferredSize: Size(
            widget.appBar.preferredSize.width,
            (widget.appBar.preferredSize.height - heightAdjustment).clamp(
              kToolbarHeight, // Minimum AppBar height
              double.infinity,
            ),
          ),
          child: widget.appBar,
        );
      },
    );
  }
}

