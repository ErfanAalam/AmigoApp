import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/call_service.dart';
import '../models/call_model.dart';

/// A call banner that integrates with the app bar system
/// This version positions the banner like a proper app bar
class AppBarCallBanner extends StatelessWidget implements PreferredSizeWidget {
  const AppBarCallBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (context, callService, child) {
        final activeCall = callService.activeCall;

        // Only show banner if there's an ongoing call (answered status)
        if (activeCall == null || activeCall.status != CallStatus.answered) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: InkWell(
              onTap: () => _navigateToCall(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
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
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Live Call',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeCall.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (activeCall.duration != null)
                            Text(
                              _formatDuration(activeCall.duration!),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 10,
                              ),
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
                          onPressed: () => callService.toggleMute(),
                          isActive: activeCall.isMuted,
                        ),

                        const SizedBox(width: 6),

                        // Speaker button
                        _buildQuickButton(
                          icon: activeCall.isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_down,
                          onPressed: () => callService.toggleSpeaker(),
                          isActive: activeCall.isSpeakerOn,
                        ),

                        const SizedBox(width: 6),

                        // End call button
                        _buildQuickButton(
                          icon: Icons.call_end,
                          onPressed: () => _endCall(context, callService),
                          isDestructive: true,
                        ),
                      ],
                    ),

                    const SizedBox(width: 8),

                    // Expand indicator
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white.withOpacity(0.7),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDestructive
              ? Colors.red.shade600
              : isActive
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 11),
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

  void _endCall(BuildContext context, CallService callService) async {
    try {
      await callService.endCall();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to end call: $e')));
      }
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(50);
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: const Icon(Icons.call, color: Colors.white, size: 12),
          ),
        );
      },
    );
  }
}
