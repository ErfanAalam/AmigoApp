import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/call_service.dart';
import '../models/call_model.dart';

class PersistentCallBanner extends StatelessWidget {
  const PersistentCallBanner({super.key});

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
          decoration: BoxDecoration(
            color: Colors.teal,
          ),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Material(
              elevation: 8,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 1, 107, 97),
                  // borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () => _navigateToCall(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
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
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade400,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.shade400
                                              .withOpacity(0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Live Call',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeCall.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (activeCall.duration != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _formatDuration(activeCall.duration!),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Quick controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Mute button
                            _buildQuickButton(
                              icon: activeCall.isMuted
                                  ? Icons.mic_off
                                  : Icons.mic,
                              onPressed: () => callService.toggleMute(),
                              isActive: activeCall.isMuted,
                            ),

                            const SizedBox(width: 12),

                            // Speaker button
                            _buildQuickButton(
                              icon: activeCall.isSpeakerOn
                                  ? Icons.volume_up
                                  : Icons.volume_down,
                              onPressed: () => callService.toggleSpeaker(),
                              isActive: activeCall.isSpeakerOn,
                            ),

                            const SizedBox(width: 12),

                            // End call button
                            _buildQuickButton(
                              icon: Icons.call_end,
                              onPressed: () => _endCall(context, callService),
                              isDestructive: true,
                            ),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // Expand indicator
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white.withOpacity(0.8),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDestructive
              ? Colors.red.shade500
              : isActive
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.15),
          border: Border.all(
            color: isDestructive
                ? Colors.red.shade300.withOpacity(0.5)
                : Colors.white.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDestructive ? Colors.red : Colors.black).withOpacity(
                0.2,
              ),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 16),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.call, color: Colors.white, size: 18),
          ),
        );
      },
    );
  }
}
