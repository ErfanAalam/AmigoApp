import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/call.provider.dart';
import '../models/call_model.dart';

class CallBanner extends ConsumerWidget {
  const CallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callServiceState = ref.watch(callServiceProvider);
    final callServiceNotifier = ref.read(callServiceProvider.notifier);
    final activeCall = callServiceState.activeCall;

    // Only show banner if there's an ongoing call (answered status)
    if (activeCall == null || activeCall.status != CallStatus.answered) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _navigateToCall(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Call icon with pulse animation
                _PulsingCallIcon(),

                const SizedBox(width: 12),

                // Call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Call in progress',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            activeCall.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (activeCall.duration != null)
                            Text(
                              _formatDuration(activeCall.duration!),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Quick controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mute button
                    _buildQuickButton(
                      icon: activeCall.isMuted ? Icons.mic_off : Icons.mic,
                      onPressed: () => callServiceNotifier.toggleMute(),
                      isActive: activeCall.isMuted,
                    ),

                    const SizedBox(width: 8),

                    // End call button
                    _buildQuickButton(
                      icon: Icons.call_end,
                      onPressed: () => _endCall(context, callServiceNotifier),
                      isDestructive: true,
                    ),
                  ],
                ),

                const SizedBox(width: 8),

                // Expand indicator
                Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDestructive
              ? Colors.red.shade600
              : isActive
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _navigateToCall(BuildContext context) {
    Navigator.of(context).pushNamed('/call');
  }

  void _endCall(
    BuildContext context,
    CallServiceNotifier callServiceNotifier,
  ) async {
    try {
      await callServiceNotifier.endCall();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to end call: $e')));
    }
  }
}

class _PulsingCallIcon extends StatefulWidget {
  @override
  State<_PulsingCallIcon> createState() => _PulsingCallIconState();
}

class _PulsingCallIconState extends State<_PulsingCallIcon>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: const Icon(Icons.call, color: Colors.white, size: 20),
          ),
        );
      },
    );
  }
}
