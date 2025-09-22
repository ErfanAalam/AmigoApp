import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/call_service.dart';
import '../models/call_model.dart';
import '../screens/call/incoming_call_screen.dart';
import '../utils/navigation_helper.dart';

class CallManager extends StatefulWidget {
  final Widget child;

  const CallManager({super.key, required this.child});

  @override
  State<CallManager> createState() => _CallManagerState();
}

class _CallManagerState extends State<CallManager> {
  bool _hasShownIncomingCall = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (context, callService, child) {
        print('[CallManager] Consumer builder called');
        print('[CallManager] CallService instance: $callService');
        print(
          '[CallManager] CallService hasActiveCall: ${callService.hasActiveCall}',
        );

        final activeCall = callService.activeCall;
        print('[CallManager] Build called - activeCall: $activeCall');
        if (activeCall != null) {
          print('[CallManager] Active call details:');
          print('  - callId: ${activeCall.callId}');
          print('  - callType: ${activeCall.callType}');
          print('  - status: ${activeCall.status}');
          print('  - userName: ${activeCall.userName}');
          print('  - hasShownIncomingCall: $_hasShownIncomingCall');
        }

        // Check if we need to show incoming call screen
        if (activeCall != null &&
            activeCall.callType == CallType.incoming &&
            activeCall.status == CallStatus.ringing &&
            !_hasShownIncomingCall) {
          print(
            '[CallManager] 🚨 INCOMING CALL DETECTED! Showing incoming call screen...',
          );
          _hasShownIncomingCall = true;

          // Show incoming call screen as an overlay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            print('[CallManager] 🚨 Executing showIncomingCallScreen callback');
            if (mounted) {
              print(
                '[CallManager] 🚨 Widget is mounted, proceeding with navigation',
              );
              _showIncomingCallScreen();
            } else {
              print(
                '[CallManager] ❌ Widget not mounted, cannot show incoming call',
              );
            }
          });
        }

        // Reset flag when call ends
        if (activeCall == null || activeCall.status == CallStatus.ended) {
          if (_hasShownIncomingCall) {
            print('[CallManager] Resetting _hasShownIncomingCall flag');
          }
          _hasShownIncomingCall = false;
        }

        return widget.child;
      },
    );
  }

  void _showIncomingCallScreen() {
    print(
      '[CallManager] 📱 _showIncomingCallScreen called - about to show dialog',
    );

    // Use NavigationHelper to navigate
    try {
      print('[CallManager] 📱 Attempting to navigate to incoming call screen');

      NavigationHelper.pushRoute(const IncomingCallScreen())
          ?.then((_) {
            print('[CallManager] 📱 Route closed - resetting flag');
            _hasShownIncomingCall = false;
          })
          .catchError((error) {
            print('[CallManager] ❌ Route error: $error');
            _hasShownIncomingCall = false;
          });

      print('[CallManager] 📱 Navigation call completed');
    } catch (e) {
      print('[CallManager] ❌ Error showing incoming call screen: $e');
      _hasShownIncomingCall = false;
    }
  }
}

/// Widget to wrap your main app content with call functionality
class CallEnabledApp extends StatelessWidget {
  final Widget child;

  const CallEnabledApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallManager(child: child);
  }
}
