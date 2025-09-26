import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/call_service.dart';
import '../../models/call_model.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    print('[IncomingCallScreen] 📱 initState called');
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
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
    return Consumer<CallService>(
      builder: (context, callService, child) {
        final activeCall = callService.activeCall;

        print('[IncomingCallScreen] 📱 Build called');
        print('[IncomingCallScreen] activeCall: $activeCall');
        if (activeCall != null) {
          print(
            '[IncomingCallScreen] activeCall.callType: ${activeCall.callType}',
          );
          print('[IncomingCallScreen] activeCall.status: ${activeCall.status}');
          print('[IncomingCallScreen] CallType.incoming: ${CallType.incoming}');
          print(
            '[IncomingCallScreen] CallStatus.ringing: ${CallStatus.ringing}',
          );
        }

        // If no active call or call was declined/ended, close the screen
        if (activeCall == null ||
            activeCall.status == CallStatus.declined ||
            activeCall.status == CallStatus.ended ||
            activeCall.status == CallStatus.missed) {
          print('[IncomingCallScreen] ❌ Call ended, declined, or missed - closing screen');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          });

          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Call ended',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // If call was answered, navigate to in-call screen
        if (activeCall.status == CallStatus.answered) {
          print('[IncomingCallScreen] ✅ Call answered - navigating to in-call screen');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/call');
            }
          });

          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Connecting...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // If not an incoming call that's ringing, show fallback
        if (activeCall.callType != CallType.incoming ||
            activeCall.status != CallStatus.ringing) {
          print('[IncomingCallScreen] ❌ Invalid call state for incoming call screen');

          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No incoming call',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      print('[IncomingCallScreen] ❌ Manual Navigator.pop()');
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        print('[IncomingCallScreen] ✅ Valid incoming call - showing UI');

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // Top section - caller info
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Incoming call',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Caller avatar with pulse animation
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: activeCall.userProfilePic != null
                                    ? Image.network(
                                        activeCall.userProfilePic!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _buildDefaultAvatar(
                                                  activeCall.userName,
                                                ),
                                      )
                                    : _buildDefaultAvatar(activeCall.userName),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // Caller name
                      Text(
                        activeCall.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Call type
                      const Text(
                        'Audio call',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom section - call actions
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Decline button
                          _buildCallActionButton(
                            icon: Icons.call_end,
                            color: Colors.red,
                            onPressed: () => _declineCall(context, callService),
                          ),

                          // Accept button
                          _buildCallActionButton(
                            icon: Icons.call,
                            color: Colors.green,
                            onPressed: () => _acceptCall(context, callService),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 50,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 35),
      ),
    );
  }

  void _acceptCall(BuildContext context, CallService callService) async {
    try {
      await callService.acceptCall();
      // Navigate to in-call screen
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/call');
      }
    } catch (e) {
      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept call: $e')));
      }
    }
  }

  void _declineCall(BuildContext context, CallService callService) async {
    try {
      await callService.declineCall();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Show error and still close
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
