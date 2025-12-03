import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_model.dart';
import '../providers/call.provider.dart';
import 'draggable_call_button.dart';
import 'global_call_bar.dart';

class CallManager extends ConsumerStatefulWidget {
  final Widget child;

  const CallManager({super.key, required this.child});

  @override
  ConsumerState<CallManager> createState() => _CallManagerState();
}

class _CallManagerState extends ConsumerState<CallManager> {
  bool _hasShownIncomingCall = false;

  @override
  Widget build(BuildContext context) {
    final callServiceState = ref.watch(callServiceProvider);

    print('[CallManager] Consumer builder called');
    print('[CallManager] CallServiceState: $callServiceState');
    print(
      '[CallManager] CallService hasActiveCall: ${callServiceState.hasActiveCall}',
    );

    final activeCall = callServiceState.activeCall;
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
          // _showIncomingCallScreen();
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

    return Column(
      children: [
        // Global call bar (appears above all content)
        const GlobalCallBar(),
        // Main app content
        Expanded(
          child: Stack(
            children: [
              widget.child,
              // Draggable call button overlay
              const DraggableCallButton(),
            ],
          ),
        ),
      ],
    );
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
