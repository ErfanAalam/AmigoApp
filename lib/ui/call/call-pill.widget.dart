import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/call.model.dart';
import '../../providers/call.provider.dart';
import '../../services/call/native_call_screen.service.dart';

/// Floating, draggable call pill that overlays the entire app during a call.
/// Replaces the old GlobalCallBar. Must be placed inside a Stack that covers
/// the full screen (e.g. via MaterialApp.builder).
class GlobalCallPill extends ConsumerStatefulWidget {
  const GlobalCallPill({super.key});

  @override
  ConsumerState<GlobalCallPill> createState() => _GlobalCallPillState();
}

class _GlobalCallPillState extends ConsumerState<GlobalCallPill>
    with TickerProviderStateMixin {
  static const double _pillWidth = 234.0;
  static const double _pillHeight = 58.0;

  // Draggable position (set on first layout)
  double _top = -1;
  double _left = -1;

  // Entrance / exit
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Pulse for incoming ringing
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.055,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _initPosition(BuildContext context) {
    if (_top < 0) {
      final mq = MediaQuery.of(context);
      _top = mq.padding.top + 12;
      _left = (mq.size.width - _pillWidth) / 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callServiceProvider);
    final activeCall = callState.activeCall;

    final bool isVisible =
        activeCall != null &&
        (activeCall.status == CallStatus.initiated ||
            activeCall.status == CallStatus.ringing ||
            activeCall.status == CallStatus.answered);

    // Drive entrance / exit
    if (isVisible && !_wasVisible) {
      _wasVisible = true;
      _enterCtrl.forward(from: 0);
    } else if (!isVisible && _wasVisible) {
      _wasVisible = false;
      _enterCtrl.reverse();
    }

    // Drive pulse only for incoming ringing
    final bool isPulse =
        activeCall?.status == CallStatus.ringing &&
        activeCall?.callType == CallType.incoming;
    if (isPulse && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!isPulse && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.animateTo(0, duration: const Duration(milliseconds: 200));
    }

    // Nothing to render
    if (!isVisible && !_enterCtrl.isAnimating) {
      return const SizedBox.shrink();
    }

    _initPosition(context);
    final Size screen = MediaQuery.of(context).size;
    final double minTop = MediaQuery.of(context).padding.top + 4;

    return Stack(
      children: [
        // Full-screen transparent layer – passes all touches through to the app
        const Positioned.fill(child: IgnorePointer(child: SizedBox.expand())),

        // The pill itself
        Positioned(
          top: _top,
          left: _left,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: GestureDetector(
                // Drag
                onPanUpdate: (d) {
                  setState(() {
                    _left = (_left + d.delta.dx).clamp(
                      8.0,
                      screen.width - _pillWidth - 8,
                    );
                    _top = (_top + d.delta.dy).clamp(
                      minTop,
                      screen.height - _pillHeight - 56,
                    );
                  });
                },
                // Tap → bring native call screen to foreground
                onTap: activeCall != null
                    ? () => _openCallScreen(activeCall)
                    : null,
                child: isPulse
                    ? ScaleTransition(
                        scale: _pulseAnim,
                        child: _buildPill(context, activeCall!),
                      )
                    : _buildPill(context, activeCall ?? _emptyState()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Pill content ──────────────────────────────────────────────────────────

  Widget _buildPill(BuildContext context, ActiveCallState call) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: _pillWidth,
          height: _pillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _pillColor(call).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: _pillColor(call).withValues(alpha: 0.38),
                blurRadius: 22,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _stateIcon(call),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        height: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText(call),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _endButton(call),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stateIcon(ActiveCallState call) {
    IconData icon;
    if (call.status == CallStatus.answered) {
      icon = Icons.call_rounded;
    } else if (call.callType == CallType.incoming) {
      icon = Icons.call_received_rounded;
    } else {
      icon = Icons.call_made_rounded;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }

  Widget _endButton(ActiveCallState call) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onEndTap(call),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE53935),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.38),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.call_end_rounded,
          color: Colors.white,
          size: 17,
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Color _pillColor(ActiveCallState call) {
    switch (call.status) {
      case CallStatus.answered:
        return const Color(0xFF1B8B3E);
      case CallStatus.ringing:
        return call.callType == CallType.incoming
            ? const Color(0xFF1B8B3E)
            : const Color(0xFF1558C0);
      case CallStatus.initiated:
      default:
        return const Color(0xFF1558C0);
    }
  }

  String _statusText(ActiveCallState call) {
    switch (call.status) {
      case CallStatus.initiated:
        return 'Calling…';
      case CallStatus.ringing:
        return call.callType == CallType.incoming
            ? 'Incoming call'
            : 'Ringing…';
      case CallStatus.connecting:
        return 'Configuring call…';
      case CallStatus.answered:
        final d = call.duration;
        if (d != null) return _fmt(d);
        return 'Connected';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.missed:
        return 'Missed call';
      case CallStatus.declined:
        return 'Call declined';
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _openCallScreen(ActiveCallState call) {
    NativeCallScreen.showCallScreen(
      callId: call.callId,
      callerName: call.userName,
      callerPhoto: call.userProfilePic,
      callMode: call.status == CallStatus.answered
          ? 'in_call'
          : call.callType == CallType.incoming
          ? 'incoming'
          : 'outgoing',
      isMuted: call.isMuted,
      isSpeakerOn: call.isSpeakerOn,
    );
  }

  void _onEndTap(ActiveCallState call) {
    final notifier = ref.read(callServiceProvider.notifier);
    if (call.status == CallStatus.ringing &&
        call.callType == CallType.incoming) {
      notifier.declineCall();
    } else {
      notifier.endCall();
    }
  }

  ActiveCallState _emptyState() => ActiveCallState(
    callId: 0,
    userId: 0,
    userName: '',
    callType: CallType.outgoing,
    status: CallStatus.initiated,
    startTime: DateTime.now(),
  );
}
