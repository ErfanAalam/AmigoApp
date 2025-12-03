import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/call.provider.dart';
import '../models/call_model.dart';

class DraggableCallButton extends ConsumerStatefulWidget {
  const DraggableCallButton({super.key});

  @override
  ConsumerState<DraggableCallButton> createState() =>
      _DraggableCallButtonState();
}

class _DraggableCallButtonState extends ConsumerState<DraggableCallButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _expandController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _expandAnimation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the call icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Expand animation for showing full button
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callServiceState = ref.watch(callServiceProvider);
    final callServiceNotifier = ref.read(callServiceProvider.notifier);
    final activeCall = callServiceState.activeCall;

    // Only show button if there's an ongoing call (answered status)
    if (activeCall == null || activeCall.status != CallStatus.answered) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 0,
      bottom: 100,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _onTap,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isExpanded ? 1.0 : 0.5,
                child: _buildCallButton(activeCall, callServiceNotifier),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(
    ActiveCallState activeCall,
    CallServiceNotifier callServiceNotifier,
  ) {
    if (_isExpanded) {
      return Container(
        width: 250,
        height: 90,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 1, 107, 97),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _buildExpandedButton(activeCall, callServiceNotifier),
      );
    } else {
      return _buildCollapsedButton(activeCall);
    }
  }

  Widget _buildCollapsedButton(ActiveCallState activeCall) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.shade500,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade500.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.call, color: Colors.white, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandedButton(
    ActiveCallState activeCall,
    CallServiceNotifier callServiceNotifier,
  ) {
    return InkWell(
      onTap: _navigateToCall,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Call icon with pulse animation
            AnimatedBuilder(
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
                    ),
                    child: const Icon(
                      Icons.call,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                );
              },
            ),

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
                        width: 12,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade400,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.shade400.withOpacity(0.5),
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
                  icon: activeCall.isMuted ? Icons.mic_off : Icons.mic,
                  onPressed: () => callServiceNotifier.toggleMute(),
                  isActive: activeCall.isMuted,
                ),

                const SizedBox(width: 8),

                // Speaker button
                _buildQuickButton(
                  icon: activeCall.isSpeakerOn
                      ? Icons.volume_up
                      : Icons.volume_down,
                  onPressed: () => callServiceNotifier.toggleSpeaker(),
                  isActive: activeCall.isSpeakerOn,
                ),

                const SizedBox(width: 8),

                // End call button
                _buildQuickButton(
                  icon: Icons.call_end,
                  onPressed: () => _endCall(callServiceNotifier),
                  isDestructive: true,
                ),
              ],
            ),
          ],
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
        width: 28,
        height: 28,
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
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  void _onTap() {
    if (_isExpanded) {
      _navigateToCall();
    } else {
      setState(() {
        _isExpanded = true;
      });
      _expandController.forward();

      // Auto-collapse after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isExpanded) {
          setState(() {
            _isExpanded = false;
          });
          _expandController.reverse();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _navigateToCall() {
    if (mounted) {
      Navigator.of(context).pushNamed('/call');
    }
  }

  void _endCall(CallServiceNotifier callServiceNotifier) async {
    try {
      await callServiceNotifier.endCall();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to end call: $e')));
      }
    }
  }
}
