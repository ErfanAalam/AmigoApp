import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/call.model.dart';
import '../../providers/call.provider.dart';
import '../../ui/snackbar.dart';

/// Global call bar that appears above all app bars when a call is ongoing
class GlobalCallBar extends ConsumerStatefulWidget {
  const GlobalCallBar({super.key});

  @override
  ConsumerState<GlobalCallBar> createState() => _GlobalCallBarState();
}

class _GlobalCallBarState extends ConsumerState<GlobalCallBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
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
    final callServiceNotifier = ref.read(callServiceProvider.notifier);
    final activeCall = callServiceState.activeCall;

    // Check if we're on the call screen or incoming call screen by checking the current route
    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);
    final String? routeName = currentRoute?.settings.name;
    final bool isOnCallScreen =
        routeName == '/call' || routeName == '/incoming-call';

    // Check if call is ongoing (initiated, ringing, or answered) and not on call screen
    final bool shouldShow =
        activeCall != null &&
        (activeCall.status == CallStatus.initiated ||
            activeCall.status == CallStatus.ringing ||
            activeCall.status == CallStatus.answered) &&
        !isOnCallScreen;

    // Debug logging only when there's an active call
    if (activeCall != null && activeCall.status != CallStatus.ended) {
      debugPrint(
        '[GlobalCallBar] status: ${activeCall.status}, shouldShow: $shouldShow, route: $routeName, duration: ${activeCall.duration}',
      );
    }

    // Animate show/hide
    if (shouldShow) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildCallBar(context, activeCall, callServiceNotifier),
      ),
    );
  }

  Widget _buildCallBar(
    BuildContext context,
    ActiveCallState? activeCall,
    CallServiceNotifier notifier,
  ) {
    if (activeCall == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black.withOpacity(0.2),
        //     blurRadius: 8,
        //     offset: const Offset(0, 2),
        //   ),
        // ],
      ),
      // child: Container(
      // top: true,
      // bottom: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToCallScreen(context),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Call icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(Icons.call, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),

                // Caller name and duration/status
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeCall.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getStatusText(activeCall),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // End call button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _endCall(context, notifier),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade600,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _getStatusText(ActiveCallState activeCall) {
    switch (activeCall.status) {
      case CallStatus.initiated:
        return 'Calling...';
      case CallStatus.ringing:
        return activeCall.callType == CallType.incoming
            ? 'Incoming call...'
            : 'Ringing...';
      case CallStatus.answered:
        if (activeCall.duration != null) {
          return _formatDuration(activeCall.duration!);
        }
        return 'Connected';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.missed:
        return 'Missed call';
      case CallStatus.declined:
        return 'Call declined';
    }
  }

  void _navigateToCallScreen(BuildContext context) {
    Navigator.of(context).pushNamed('/call');
  }

  void _endCall(BuildContext context, CallServiceNotifier notifier) async {
    try {
      await notifier.endCall();
    } catch (e) {
      if (context.mounted) {
        Snack.error('Failed to end call: $e');
      }
    }
  }
}
