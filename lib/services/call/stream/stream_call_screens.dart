import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:floating/floating.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'stream_call.service.dart';

/// Top-level call surface.
///
/// Responsibilities:
///  - Renders the right state-specific view (incoming / outgoing / in-call)
///    by delegating to [StreamCallContainer]'s builder slots.
///  - Holds the keep-screen-on / show-on-lockscreen flags for as long as the
///    screen is mounted, by toggling Android's MainActivity flags via the
///    existing `com.aiexch.amigo/lock_screen` MethodChannel.
///  - Exposes a static [isMounted] flag so the call pill / dispatcher can
///    avoid pushing the route twice.
///  - Propagates a [callerHint] (name / avatar known up-front) down the tree
///    so the screen never shows "Unknown" while we wait for the SDK to send
///    participant join events.
class StreamCallScreen extends StatefulWidget {
  final Call call;

  /// Optional pre-known display info for the remote party. The dispatcher
  /// fills this from the chat row on outgoing calls, and from the call's
  /// `members` metadata on incoming calls.
  final CallerHint? callerHint;

  const StreamCallScreen({super.key, required this.call, this.callerHint});

  static bool isMounted = false;

  /// Reactive flag — UI elsewhere (the global call pill) listens to this to
  /// know whether the call screen is currently on top. Updated on
  /// initState/dispose of the screen state.
  static final ValueNotifier<bool> isMountedNotifier = ValueNotifier(false);

  /// Looks up the [CallerHint] in the widget tree (provided by the screen).
  /// Used by `_ActiveCallView` so it can surface name/avatar before the SFU
  /// has emitted the first participant-joined event.
  static CallerHint? fallbackOf(BuildContext context) {
    final inh = context
        .dependOnInheritedWidgetOfExactType<_CallerHintScope>();
    return inh?.hint;
  }

  @override
  State<StreamCallScreen> createState() => _StreamCallScreenState();
}

/// Lightweight POD threaded through the call screen so the UI has something
/// to render before the SFU exchanges participant info.
class CallerHint {
  final String? userId;
  final String? userName;
  final String? userProfilePic;
  const CallerHint({this.userId, this.userName, this.userProfilePic});
}

class _CallerHintScope extends InheritedWidget {
  final CallerHint? hint;
  const _CallerHintScope({required this.hint, required super.child});
  @override
  bool updateShouldNotify(_CallerHintScope oldWidget) =>
      oldWidget.hint != hint;
}

/// Connect options for an audio-only call. The user can flip the camera on
/// later from the in-call control bar.
final CallConnectOptions audioOnlyConnect = CallConnectOptions(
  camera: TrackOption.disabled(),
  microphone: TrackOption.enabled(),
);

/// Connect options for a video call. Both camera and microphone start
/// enabled. We branch on `call.state.value.settings.video.enabled` to pick
/// between this and [audioOnlyConnect] in [StreamCallService.ensureJoined].
final CallConnectOptions videoConnect = CallConnectOptions(
  camera: TrackOption.enabled(),
  microphone: TrackOption.enabled(),
);

// ───────────────────────────────────────────────────────────────────────────
// Call ended overlay
// ───────────────────────────────────────────────────────────────────────────

/// Static screen shown for ~2 seconds after the call disconnects, before the
/// route pops. Replaces the live in-call UI so all the bottom controls become
/// unreachable instantly (avoiding double-end-call taps and a frozen-looking
/// in-call view while the linger plays out).
class _CallEndedOverlay extends StatelessWidget {
  final DisconnectReason reason;
  final String? fallbackName;
  final String? fallbackImage;

  const _CallEndedOverlay({
    required this.reason,
    this.fallbackName,
    this.fallbackImage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _BlurredAvatarBackdrop(imageUrl: fallbackImage),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Color(0xFFE53935),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  fallbackName ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                // The timeout flag can flip a beat after this overlay first
                // paints (the Stream `Rejected` event can beat our WS
                // `timeout` signal to the peer), so listen reactively and
                // prefer "Call timeout" whenever the watchdog ended the call.
                ValueListenableBuilder<bool>(
                  valueListenable: StreamCallService().endedByTimeout,
                  builder: (context, timedOut, _) => Text(
                    timedOut ? 'Call timeout' : _label(reason),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _label(DisconnectReason r) {
    final s = r.toString().toLowerCase();
    if (s.contains('reject')) return 'Call declined';
    if (s.contains('timeout') || s.contains('cancel')) return 'Call missed';
    if (s.contains('failure') || s.contains('error')) return 'Call ended';
    return 'Call ended';
  }
}

class _StreamCallScreenState extends State<StreamCallScreen> {
  StreamSubscription<CallState>? _stateSub;
  bool _outgoingJoined = false;
  Timer? _disconnectPopTimer;
  // The disconnect reason the SDK reported, used to pick the overlay copy.
  // Null while the call is live.
  DisconnectReason? _disconnectReason;

  // Picture-in-Picture is armed via `OnLeavePiP` whenever any participant
  // (local or remote) has video on. The Floating package then triggers PiP
  // automatically when the user navigates away (Home gesture) — no manual
  // lifecycle plumbing needed. We re-arm/disarm whenever the video flag
  // flips so audio-only calls don't accidentally enter PiP.
  final Floating? _floating = defaultTargetPlatform == TargetPlatform.android
      ? Floating()
      : null;
  bool _pipArmed = false;

  @override
  void initState() {
    super.initState();
    StreamCallScreen.isMounted = true;
    // Defer the ValueNotifier update to the next frame — flipping it
    // synchronously inside initState fires the pill's ValueListenableBuilder
    // while the framework is still building, throwing
    // `setState() called during build` warnings.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StreamCallScreen.isMountedNotifier.value = true;
    });
    StreamCallService().enableLockScreenFlags();

    // Drive the call state machine ourselves. We deliberately do NOT use
    // `StreamCallContainer` because it auto-calls `call.join()` in initState
    // — for an incoming call that implicitly accepts it, so the SDK's status
    // never reports `CallStatusIncoming{acceptedByMe:false}` long enough for
    // a ringing UI to render and the caller's side fires a Rejected event.
    _bindStateMachine();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _disconnectPopTimer?.cancel();
    if (_pipArmed) {
      _floating?.cancelOnLeavePiP();
    }
    StreamCallScreen.isMounted = false;
    // Defer the notifier update — pushing it during dispose throws
    // `setState() called when widget tree was locked` because it would
    // mark the pill as needing rebuild while the framework is tearing
    // this widget down.
    final notifier = StreamCallScreen.isMountedNotifier;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.value = false;
    });
    StreamCallService().disableLockScreenFlags();
    super.dispose();
  }

  void _bindStateMachine() {
    final call = widget.call;
    final initial = call.state.value;
    _maybeJoinAsOutgoing(initial);
    _autoPopOnDisconnect(initial);
    _maybeArmPiP(initial);

    _stateSub = call.state.valueStream.listen((s) {
      _maybeJoinAsOutgoing(s);
      _autoPopOnDisconnect(s);
      _maybeArmPiP(s);
    });
  }

  /// Arm/disarm Picture-in-Picture based on whether any participant has
  /// video on. Only Android — iOS uses CallKit's native PiP path which
  /// the SDK manages itself.
  void _maybeArmPiP(CallState s) {
    final f = _floating;
    if (f == null) return;
    final localVideo = s.localParticipant?.isVideoEnabled ?? false;
    final remoteVideo = s.callParticipants.any((p) =>
        !p.isLocal &&
        p.publishedTracks[SfuTrackType.video] != null &&
        !p.isTrackPaused(SfuTrackType.video));
    final shouldArm = localVideo || remoteVideo;
    if (shouldArm == _pipArmed) return;
    _pipArmed = shouldArm;
    if (shouldArm) {
      // OnLeavePiP arms the system to enter PiP automatically when the
      // user backgrounds the app (Home gesture). We request a portrait
      // (9:16) aspect ratio — a tall PiP tile reads better when the
      // remote feed is a person.
      f.enable(const OnLeavePiP(aspectRatio: Rational.vertical()))
          .catchError((Object e) {
        debugPrint('[STREAM-CALL]   PiP enable failed: $e');
        return PiPStatus.unavailable;
      });
    } else {
      f.cancelOnLeavePiP();
    }
  }

  /// Drive `call.join()` once the call has progressed past the ringing
  /// phase. We deliberately wait for `acceptedByCallee:true` on outgoing
  /// calls because calling `join()` while still ringing puts the SDK into
  /// `_awaitIfNeeded` — a 30s waiting state that, if anything cancels the
  /// underlying cancelable, makes `_doJoin` fire `reject(timeout())`. That
  /// reject ends the call from the caller's user account, so the callee
  /// sees "Call declined" and the caller gets a ghost call. Joining only
  /// after the callee has accepted bypasses that wait entirely.
  void _maybeJoinAsOutgoing(CallState s) {
    if (_outgoingJoined) return;
    final status = s.status;
    // Don't even consider joining a terminal call. Same reasoning as the
    // initState guard: prevents a getUserMedia()-induced mic leak when the
    // disconnect race ends up here.
    if (status is CallStatusDisconnected || status is CallStatusReconnectionFailed) {
      return;
    }
    final shouldJoin =
        // Caller path: only join after the callee has actually accepted.
        (status is CallStatusOutgoing && status.acceptedByCallee) ||
            // Callee path & post-accept resync: status is already past
            // ringing, safe to (re)issue join().
            status is CallStatusJoining ||
            status is CallStatusConnecting;
    if (shouldJoin) {
      _outgoingJoined = true;
      debugPrint('[STREAM-CALL]   ensureJoined called from screen for '
          '$status');
      // ignore: unawaited_futures
      StreamCallService().ensureJoined(widget.call);
    }
  }

  /// When the SDK reports a disconnect, render a short "Call ended" overlay
  /// (controls are disabled simultaneously) and pop after 2s. This avoids the
  /// jarring instant-pop that previously made the UI feel laggy.
  void _autoPopOnDisconnect(CallState s) {
    if (s.status is CallStatusDisconnected && _disconnectReason == null) {
      final reason = (s.status as CallStatusDisconnected).reason;
      debugPrint('[STREAM-CALL] disconnect status seen ($reason) — '
          'showing 2s linger then popping');
      // Defer the setState — when the listener fires synchronously during
      // initial _bindStateMachine, calling setState would error out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _disconnectReason = reason);
      });
      _disconnectPopTimer?.cancel();
      _disconnectPopTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CallerHintScope(
      hint: widget.callerHint,
      child: WillPopScope(
        // Don't tear the call down on system-back; leave the screen but keep
        // the call running. The pill brings the screen back.
        onWillPop: () async => true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: StreamBuilder<CallState>(
            stream: widget.call.state.valueStream,
            initialData: widget.call.state.value,
            builder: (context, snap) {
              final s = snap.data ?? widget.call.state.value;
              final status = s.status;

              // Disconnect state — render a static overlay until the 2-second
              // pop timer fires. Block touches on the rest of the screen so
              // the user can't accidentally hit "End call" twice.
              if (_disconnectReason != null) {
                return _CallEndedOverlay(
                  reason: _disconnectReason!,
                  fallbackName: StreamCallScreen.fallbackOf(context)?.userName,
                  fallbackImage:
                      StreamCallScreen.fallbackOf(context)?.userProfilePic,
                );
              }

              if (status is CallStatusIncoming && !status.acceptedByMe) {
                return _RingingView(
                  call: widget.call,
                  mode: _RingingMode.incoming,
                );
              }
              if (status is CallStatusOutgoing && !status.acceptedByCallee) {
                return _RingingView(
                  call: widget.call,
                  mode: _RingingMode.outgoing,
                );
              }
              return _ActiveCallView(call: widget.call);
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Shared decoration: blurred profile-pic background
// ───────────────────────────────────────────────────────────────────────────

/// Blurred network-image background. Falls back to a dark gradient when no
/// PFP URL is available, so the screen never looks empty.
class _BlurredAvatarBackdrop extends StatelessWidget {
  final String? imageUrl;

  const _BlurredAvatarBackdrop({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null && imageUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const _GradientBackdrop(),
            placeholder: (_, __) => const _GradientBackdrop(),
          )
        else
          const _GradientBackdrop(),
        // Heavy blur + dim so foreground content stays readable.
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1B33), Color(0xFF1F0F33), Color(0xFF000000)],
        ),
      ),
    );
  }
}

/// Extracts a remote participant's avatar URL from call state, falling back to
/// the call's first non-self member.
///
/// IMPORTANT: filter by `p.userId != state.currentUserId`. Without it, the
/// first participant in the list wins regardless of which side they're on —
/// once both parties have joined, that "first" entry is whichever Stream
/// inserted first (typically the caller), so both caller and callee end up
/// rendering the caller's PFP.
String? _remoteAvatar(CallState state) {
  for (final p in state.callParticipants) {
    if (p.userId == state.currentUserId) continue;
    if (p.image != null && p.image!.isNotEmpty) return p.image;
  }
  // Members are populated even before participants connect (incoming-call case).
  for (final m in state.callMembers) {
    if (m.userId != state.currentUserId && m.image != null && m.image!.isNotEmpty) {
      return m.image;
    }
  }
  return null;
}

/// Display name for the remote party. Tries connected participants first, then
/// the call's member list (populated as soon as the call is created), then a
/// caller-provided fallback (e.g. "Calling Riya" → name from the chat row),
/// before giving up with "Unknown".
String _remoteName(CallState state, [String? fallback]) {
  for (final p in state.callParticipants) {
    if (p.userId != state.currentUserId) {
      if (p.name.isNotEmpty) return p.name;
      // userId is a UUID — only return it if we have nothing better.
    }
  }
  for (final m in state.callMembers) {
    if (m.userId != state.currentUserId) {
      if ((m.name?.isNotEmpty ?? false)) return m.name!;
    }
  }
  if (fallback != null && fallback.isNotEmpty) return fallback;
  // Last resort: surface the user id so debugging is possible — never return
  // a literal "Unknown" if we have any identity at all.
  for (final p in state.callParticipants) {
    if (p.userId != state.currentUserId) return p.userId;
  }
  for (final m in state.callMembers) {
    if (m.userId != state.currentUserId) return m.userId;
  }
  return 'Unknown';
}

// ───────────────────────────────────────────────────────────────────────────
// Ringing screens (incoming + outgoing)
// ───────────────────────────────────────────────────────────────────────────

enum _RingingMode { incoming, outgoing }

class _RingingView extends StatelessWidget {
  final Call call;
  final _RingingMode mode;

  const _RingingView({required this.call, required this.mode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CallState>(
      stream: call.state.valueStream,
      initialData: call.state.value,
      builder: (context, snap) {
        final s = snap.data ?? call.state.value;
        final fallback = StreamCallScreen.fallbackOf(context);
        final avatarUrl = _remoteAvatar(s) ?? fallback?.userProfilePic;
        final name = _remoteName(s, fallback?.userName);
        final subtitle = mode == _RingingMode.incoming
            ? 'Incoming voice call'
            : 'Calling…';

        return Stack(
          fit: StackFit.expand,
          children: [
            _BlurredAvatarBackdrop(imageUrl: avatarUrl),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Amigo',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(flex: 1),
                    _PulsingAvatar(imageUrl: avatarUrl, name: name),
                    const SizedBox(height: 28),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (mode == _RingingMode.outgoing) const _RingingDots(),
                    const Spacer(flex: 2),
                    if (mode == _RingingMode.incoming)
                      _IncomingActionRow(call: call)
                    else
                      _OutgoingActionRow(call: call),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PulsingAvatar extends StatefulWidget {
  final String? imageUrl;
  final String name;

  const _PulsingAvatar({required this.imageUrl, required this.name});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++) _buildPulse(i),
              child!,
            ],
          );
        },
        child: _CircleAvatar(imageUrl: widget.imageUrl, name: widget.name, size: 140),
      ),
    );
  }

  Widget _buildPulse(int index) {
    final progress = ((_ctrl.value + index / 3) % 1.0);
    final scale = 0.65 + (progress * 0.7);
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.45;
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: opacity),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;

  const _CircleAvatar({
    required this.imageUrl,
    required this.name,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage
            ? null
            : const LinearGradient(
                colors: [Color(0xFF6F86FF), Color(0xFFB46BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initialsTile(initials),
              )
            : _initialsTile(initials),
      ),
    );
  }

  Widget _initialsTile(String initials) => Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _RingingDots extends StatefulWidget {
  const _RingingDots();

  @override
  State<_RingingDots> createState() => _RingingDotsState();
}

class _RingingDotsState extends State<_RingingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = ((_ctrl.value + i / 3) % 1.0);
            final scale = 0.6 + (1 - (2 * t - 1).abs()) * 0.6;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Action rows
// ───────────────────────────────────────────────────────────────────────────

class _IncomingActionRow extends StatelessWidget {
  final Call call;
  const _IncomingActionRow({required this.call});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundActionButton(
          icon: Icons.call_end_rounded,
          color: const Color(0xFFE53935),
          label: 'Decline',
          onTap: () async {
            debugPrint('[STREAM-UI] 🔘 in-app DECLINE tapped  '
                'cid=${call.callCid.value}  status=${call.state.value.status.runtimeType}');
            // Route through the service so we get the Amigo `call:terminate`
            // WS dispatch alongside Stream's `reject()`.
            await StreamCallService().declineCall(reason: 'user_declined');
            if (context.mounted) Navigator.of(context).maybePop();
          },
        ),
        _RoundActionButton(
          icon: Icons.call_rounded,
          color: const Color(0xFF20C26A),
          label: 'Accept',
          onTap: () async {
            debugPrint('[STREAM-UI] 🔘 in-app ACCEPT tapped  '
                'cid=${call.callCid.value}  status=${call.state.value.status.runtimeType}');
            final res = await call.accept();
            debugPrint('[STREAM-UI]   accept() → success=${res.isSuccess}  '
                'postStatus=${call.state.value.status.runtimeType}');
            // Use the centralised helper so `_joinedCid` is tracked and a
            // subsequent screen-side _maybeJoinAsOutgoing won't double-join.
            await StreamCallService().ensureJoined(call);
          },
        ),
      ],
    );
  }
}

class _OutgoingActionRow extends StatelessWidget {
  final Call call;
  const _OutgoingActionRow({required this.call});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _RoundActionButton(
        icon: Icons.call_end_rounded,
        color: const Color(0xFFE53935),
        label: 'Cancel',
        onTap: () async {
          debugPrint('[STREAM-UI] 🔘 outgoing CANCEL tapped  '
              'cid=${call.callCid.value}  status=${call.state.value.status.runtimeType}');
          // Route through the service so we (a) dispatch Amigo's
          // `call:terminate` WS event and (b) use `call.end()` instead of
          // `call.leave()` — without `end()`, the callee's Stream client
          // keeps ringing until timeout because `leave()` only exits our
          // own session.
          await StreamCallService().endCall(reason: 'caller_cancelled');
          if (context.mounted) Navigator.of(context).maybePop();
        },
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final double size;

  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          shape: const CircleBorder(),
          color: color,
          elevation: 6,
          shadowColor: color.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: size * 0.42),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Active in-call view
// ───────────────────────────────────────────────────────────────────────────

class _ActiveCallView extends StatefulWidget {
  final Call call;
  const _ActiveCallView({required this.call});

  @override
  State<_ActiveCallView> createState() => _ActiveCallViewState();
}

class _ActiveCallViewState extends State<_ActiveCallView> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  // Real PiP state, driven by Floating's status stream. We used to derive
  // this from MediaQuery width but Android's display-zoom setting can push
  // the reported width below the legacy threshold on tablets and large
  // phones, making the in-call UI collapse to PiP layout even when the
  // call screen is fullscreen. The status stream reflects the OS's actual
  // PiP state. `Floating()` is a singleton so this co-exists fine with the
  // parent screen's arming logic.
  final Floating? _floating = defaultTargetPlatform == TargetPlatform.android
      ? Floating()
      : null;
  StreamSubscription<PiPStatus>? _pipStatusSub;
  bool _isInPip = false;

  /// Subscription that drives native screen behavior (proximity wake lock
  /// vs FLAG_KEEP_SCREEN_ON) based on whether any video is on. We mirror
  /// the same `anyRemoteVideo || localVideoOn` condition used by the
  /// build, so the mode stays in lock-step with the visible layout.
  StreamSubscription<CallState>? _screenModeSub;
  String? _lastScreenMode;

  @override
  void initState() {
    super.initState();
    final pipStream = _floating?.pipStatusStream;
    if (pipStream != null) {
      _pipStatusSub = pipStream.listen((status) {
        if (!mounted) return;
        final next = status == PiPStatus.enabled;
        if (next != _isInPip) setState(() => _isInPip = next);
      });
    }

    // Apply the initial screen mode synchronously, then keep it tracking
    // the live state of the call. Without the initial apply, an audio
    // call would never get the proximity lock until the first
    // post-initState state event lands (which can be hundreds of ms
    // later — long enough to press the phone to your ear and have it
    // light up your face).
    _applyScreenModeFor(widget.call.state.value);
    _screenModeSub = widget.call.state.valueStream.listen(_applyScreenModeFor);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Read the canonical "connected at" from the service so the on-screen
      // counter stays in lock-step with the persistent ongoing-call
      // notification (which is anchored to the same DateTime via Android's
      // chronometer). When the anchor isn't pinned yet (we've joined the
      // SFU but the remote party's audio path hasn't completed — the
      // ~4-5s "real silence" window) we keep _elapsed at zero; the build
      // method renders a 'Connecting…' label in that case rather than a
      // running 00:00, 00:01… over silence. See StreamCallService
      // `_audioReadyFallbackTimer` for the gating logic.
      final start = StreamCallService().callConnectedAt;
      setState(() {
        _elapsed = start == null
            ? Duration.zero
            : DateTime.now().difference(start);
      });
    });

    // Belt-and-braces: if we're already past the ringing phase but the call
    // was never joined (e.g. we got here via consumeAndAcceptActiveCall on
    // cold-start, which only calls accept()), fire the join now.
    //
    // Skip when the call is already terminal — the screen lingers for 2s
    // after a cancel/reject before popping, and during that window the
    // build/state cycle would otherwise drive a fresh join() into a dead
    // call, capturing the mic via getUserMedia and never releasing it.
    // `ensureJoined` has its own guard for this, but bailing here avoids
    // the wasted SDK round-trip entirely.
    final status = widget.call.state.value.status;
    if (status is CallStatusDisconnected || status is CallStatusReconnectionFailed) {
      debugPrint('[STREAM-CALL]   screen init: $status — skip ensureJoined');
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: unawaited_futures
        StreamCallService().ensureJoined(widget.call);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pipStatusSub?.cancel();
    _screenModeSub?.cancel();
    // Release the proximity wake lock + FLAG_KEEP_SCREEN_ON before the
    // widget tears down. Without this, an audio call that ended with the
    // user still holding the phone to their ear would leave the screen
    // off until the sensor was uncovered.
    StreamCallService().setCallScreenMode('none');
    _lastScreenMode = null;
    super.dispose();
  }

  /// Computes the desired screen mode for the current call state and
  /// forwards it to the native side ONLY when it changes — re-invoking
  /// the channel on every state event would be wasteful (and would also
  /// thrash the proximity wake lock if any of the underlying flags were
  /// less idempotent than they currently are).
  void _applyScreenModeFor(CallState state) {
    final localVideoOn = state.localParticipant?.isVideoEnabled ?? false;
    final anyRemoteVideo = state.callParticipants
        .where((p) => !p.isLocal)
        .any(
          (p) =>
              p.publishedTracks[SfuTrackType.video] != null &&
              !p.isTrackPaused(SfuTrackType.video),
        );
    final mode = (localVideoOn || anyRemoteVideo) ? 'video' : 'audio';
    if (mode == _lastScreenMode) return;
    _lastScreenMode = mode;
    StreamCallService().setCallScreenMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CallState>(
      stream: widget.call.state.valueStream,
      initialData: widget.call.state.value,
      builder: (context, snap) {
        final state = snap.data ?? widget.call.state.value;

        // Local + remote participant lists. `state.localParticipant` is null
        // until the local user has joined the SFU; tolerate that.
        final localUser = state.localParticipant;
        final remoteParticipants = state.callParticipants
            .where((p) => !p.isLocal)
            .toList();

        // Audio mode = nobody has video on. We still render this safely even
        // if `state.callParticipants` is empty during the brief connecting
        // window — that was crashing on `.first` before.
        final anyRemoteVideo = remoteParticipants.any(
          (p) =>
              p.publishedTracks[SfuTrackType.video] != null &&
              !p.isTrackPaused(SfuTrackType.video),
        );
        final localVideoOn = localUser?.isVideoEnabled ?? false;
        final isAudioMode = !anyRemoteVideo && !localVideoOn;

        // Fall back to the call's stored caller name/avatar (set during
        // ringing) so we never have to show "Unknown" while we wait for the
        // first participant join event.
        final fallback = StreamCallScreen.fallbackOf(context);
        final remoteName = _remoteName(state, fallback?.userName);
        final remoteAvatar = _remoteAvatar(state) ?? fallback?.userProfilePic;

        // PiP state comes from the Floating package's status stream — see
        // `_pipStatusSub` in initState. In PiP we drop the top status bar,
        // the self-view tile and the entire control bar so the remote
        // video/avatar gets the whole tile.
        final isPip = _isInPip;

        debugPrint('[STREAM-CALL] in-call build  '
            'callParticipants=${state.callParticipants.length} '
            'remote=${remoteParticipants.length} '
            'local?${localUser != null} videoOn=$localVideoOn '
            'audioMode=$isAudioMode pip=$isPip name="$remoteName"');

        // Pick the top-bar duration label based on whether the call has
        // actually reached audio-ready state. We mirror the service's
        // anchor (`callConnectedAt`) so the on-screen counter doesn't
        // tick over the ~4-5s of SFU/ICE setup silence; during that
        // window the user sees "Connecting…" instead.
        final audioReady = StreamCallService().callConnectedAt != null;
        final streamStatus = state.status;
        final String durationLabel;
        if (audioReady) {
          durationLabel = _fmt(_elapsed);
        } else if (streamStatus is CallStatusOutgoing) {
          durationLabel = 'Calling…';
        } else if (streamStatus is CallStatusIncoming) {
          durationLabel = 'Incoming call';
        } else {
          durationLabel = 'Connecting…';
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (isAudioMode || remoteParticipants.isEmpty)
              _BlurredAvatarBackdrop(imageUrl: remoteAvatar)
            else
              _VideoGrid(call: widget.call, participants: remoteParticipants),

            if (isAudioMode || remoteParticipants.isEmpty)
              _audioBody(remoteAvatar, remoteName, durationLabel),

            // Self-view PiP when video is on. Guarded — only when localUser
            // is non-null so we never crash. Hidden in PiP because there's
            // no room for it.
            if (!isAudioMode && localVideoOn && localUser != null && !isPip)
              Positioned(
                top: 24 + MediaQuery.of(context).padding.top,
                right: 16,
                child: _SelfViewTile(call: widget.call, participant: localUser),
              ),

            // Top status bar — hidden in PiP.
            if (!isPip)
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 0,
              right: 0,
              child: _TopBar(
                name: remoteName,
                durationLabel: durationLabel,
                showBackPill: !isAudioMode,
              ),
            ),

            // Bottom controls — hidden entirely in PiP. The PiP tile is
            // too small to host any touch target; the user returns to
            // full screen first and then interacts with the controls.
            if (!isPip)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                    child: _ControlBar(call: widget.call, state: state),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _audioBody(String? avatar, String name, String durationLabel) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            _CircleAvatar(imageUrl: avatar, name: name, size: 160),
            const SizedBox(height: 26),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              durationLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Top bar + controls
// ───────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String name;
  final String durationLabel;
  final bool showBackPill;

  const _TopBar({
    required this.name,
    required this.durationLabel,
    this.showBackPill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.expand_more_rounded, color: Colors.white, size: 30),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Minimize',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  durationLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ControlBar extends StatefulWidget {
  final Call call;
  final CallState state;

  const _ControlBar({required this.call, required this.state});

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  // Track the user's mic *intent*. Defaults to "unmuted" because we always
  // join with `audioOnlyConnect` (microphone: enabled). Only the user's tap
  // on the mute button flips this; SDK state changes don't.
  //
  // The previous "if me==null return false" fix was insufficient: once the
  // SFU populates `localParticipant`, there's still a ~1 s window before
  // the audio track is published, during which `isAudioEnabled` is false
  // and the icon would flicker to "muted". We trust intent until the SFU
  // confirms audio at least once (`_everSawAudioEnabled`) — after that the
  // SDK's state is reliable.
  bool _userMuted = false;
  bool _everSawAudioEnabled = false;

  bool get _muted {
    final me = widget.state.localParticipant;
    if (me?.isAudioEnabled == true) {
      _everSawAudioEnabled = true;
    }
    if (!_everSawAudioEnabled) return _userMuted;
    return !(me?.isAudioEnabled ?? false);
  }

  bool get _videoOn {
    // For video the safe default is `false` because `audioOnlyConnect`
    // disables the camera. Only reflect `isVideoEnabled` once SFU sync
    // catches up.
    final me = widget.state.localParticipant;
    return me?.isVideoEnabled ?? false;
  }

  Future<void> _toggleMute() async {
    final nextMuted = !_muted;
    setState(() => _userMuted = nextMuted);
    await widget.call.setMicrophoneEnabled(enabled: !nextMuted);
  }

  /// Opens a bottom sheet listing every available audio output (earpiece,
  /// speaker, connected Bluetooth, wired headset, …) and lets the user
  /// pick one. Reactive to hot-plug: a Bluetooth headset connecting /
  /// disconnecting while the sheet is open updates the list live
  /// (`RtcMediaDeviceNotifier.onDeviceChange`).
  ///
  /// Replaces the old 2-state speaker toggle, which couldn't represent
  /// "user is on a Bluetooth headset" as anything other than off.
  Future<void> _openAudioOutputPicker() async {
    final initial =
        (await RtcMediaDeviceNotifier.instance.audioOutputs())
            .getDataOrNull() ??
        const <RtcMediaDevice>[];

    if (!mounted) return;
    // Capture `call` up-front; the bottom-sheet builder runs in its own
    // BuildContext that doesn't see our widget state, and we want every
    // tap to use the same Call instance the bar is bound to.
    final call = widget.call;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: StreamBuilder<List<RtcMediaDevice>>(
          stream: RtcMediaDeviceNotifier.instance.onDeviceChange,
          initialData: initial,
          builder: (ctx, snap) {
            final outputs = (snap.data ?? const <RtcMediaDevice>[])
                .where((d) => d.kind == RtcMediaDeviceKind.audioOutput)
                .toList();
            // Re-read the call state on every build so the check-mark
            // moves immediately after a selection.
            final currentId = call.state.value.audioOutputDevice?.id;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Audio output',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (outputs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Text(
                      'No audio output devices found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                for (final d in outputs)
                  ListTile(
                    leading: Icon(
                      _AudioOutputUi.iconFor(d),
                      color: Colors.white,
                    ),
                    title: Text(
                      _AudioOutputUi.labelFor(d),
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: d.id == currentId
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF4CD964),
                          )
                        : null,
                    onTap: () async {
                      try {
                        await call.setAudioOutputDevice(d);
                      } catch (e) {
                        debugPrint('[STREAM-CALL] audio-picker: '
                            'setAudioOutputDevice failed: $e');
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );

    // The bar icon mirrors the current device; pump a frame so it
    // refreshes when the sheet closes even if `widget.state` hasn't
    // rebuilt yet (the call.state stream will catch up momentarily).
    if (mounted) setState(() {});
  }

  Future<void> _toggleVideo() async {
    await widget.call.setCameraEnabled(enabled: !_videoOn);
  }

  Future<void> _flip() async {
    await widget.call.flipCamera();
  }

  Future<void> _hangup() async {
    debugPrint('[STREAM-UI] 🔘 in-call HANGUP tapped  '
        'cid=${widget.call.callCid.value}  status=${widget.call.state.value.status.runtimeType}');
    final res = await widget.call.leave();
    debugPrint('[STREAM-UI]   leave() → success=${res.isSuccess}');
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // The control bar is never rendered in PiP (the parent skips it), so
    // sizing only has to handle in-call full-screen layouts. We pin the
    // bar to at least 80% of the screen width so it reads as a real
    // bottom bar, and cap it at `maxWidth` so it doesn't stretch
    // edge-to-edge on tablets. If 80% of the screen exceeds the cap,
    // the cap wins.
    const maxWidth = 480.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final eightyPercent = screenWidth * 0.8;
    final minWidth = eightyPercent > maxWidth ? maxWidth : eightyPercent;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 0.6,
                ),
              ),
              // Wrap (not Row) so the bar grows a second row when buttons
              // don't fit horizontally — happens on narrower phones once
              // the flip-camera button shows up alongside mute/speaker/
              // video/hangup.
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PillButton(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    active: _muted,
                    onTap: _toggleMute,
                  ),
                  _PillButton(
                    // Icon mirrors the currently-selected audio output
                    // (earpiece / speaker / BT / wired). `active` lights
                    // the pill whenever audio is NOT on the earpiece —
                    // so the user can tell at a glance that they're on
                    // speaker or a headset without opening the sheet.
                    icon: _AudioOutputUi.iconFor(
                      widget.state.audioOutputDevice,
                    ),
                    active: widget.state.audioOutputDevice != null &&
                        !(widget.state.audioOutputDevice!.isEarpiece),
                    onTap: _openAudioOutputPicker,
                  ),
                  _PillButton(
                    icon: _videoOn
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    active: _videoOn,
                    onTap: _toggleVideo,
                  ),
                  if (_videoOn)
                    _PillButton(
                      icon: Icons.cameraswitch_rounded,
                      active: false,
                      onTap: _flip,
                    ),
                  _PillButton(
                    icon: Icons.call_end_rounded,
                    active: true,
                    color: const Color(0xFFE53935),
                    onTap: _hangup,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small helpers for rendering an audio output device — icon and a
/// human-readable label. Used by both the in-call control bar's speaker
/// pill (when `audioOutputDevice` is non-null) and the audio-output
/// bottom-sheet picker.
class _AudioOutputUi {
  const _AudioOutputUi._();

  /// Icon for the given device. Returns the default "tap to pick output"
  /// icon when the SDK hasn't told us which device is active yet
  /// (the call.state hasn't propagated `audioOutputDevice` post-join).
  static IconData iconFor(RtcMediaDevice? d) {
    if (d == null) return Icons.hearing_rounded;
    if (d.isSpeaker) return Icons.volume_up_rounded;
    if (d.isEarpiece) return Icons.hearing_rounded;
    if (d.isExternal) {
      final label = d.label.toLowerCase();
      if (label.contains('bluetooth') || label.contains('bt')) {
        return Icons.bluetooth_audio_rounded;
      }
      if (label.contains('wired') || label.contains('headset')) {
        return Icons.headset_rounded;
      }
      return Icons.headphones_rounded;
    }
    return Icons.speaker_rounded;
  }

  /// Humane label. Android often reports the raw groupId / type as the
  /// label, which looks like 'bluetooth' or just '' — rewrite the common
  /// cases so the picker reads naturally.
  static String labelFor(RtcMediaDevice d) {
    if (d.isEarpiece) return 'Earpiece';
    if (d.isSpeaker) return 'Speaker';
    if (d.label.isEmpty) {
      if (d.isExternal) return 'Headphones';
      return d.id;
    }
    return d.label;
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  const _PillButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        color ?? (active ? Colors.white : Colors.white.withValues(alpha: 0.10));
    final fg =
        color != null ? Colors.white : (active ? Colors.black : Colors.white);
    return Material(
      shape: const CircleBorder(),
      color: bg,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: fg, size: 24),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Video grid
// ───────────────────────────────────────────────────────────────────────────

class _VideoGrid extends StatelessWidget {
  final Call call;
  final List<CallParticipantState> participants;
  const _VideoGrid({required this.call, required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const _GradientBackdrop();
    if (participants.length == 1) {
      return _VideoTile(call: call, participant: participants.first, fill: true);
    }
    final cols = participants.length <= 2 ? 1 : 2;
    return GridView.count(
      crossAxisCount: cols,
      padding: EdgeInsets.zero,
      children: [
        for (final p in participants) _VideoTile(call: call, participant: p),
      ],
    );
  }
}

class _VideoTile extends StatelessWidget {
  final Call call;
  final CallParticipantState participant;
  final bool fill;
  const _VideoTile({
    required this.call,
    required this.participant,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: StreamVideoRenderer(
        call: call,
        participant: participant,
        videoTrackType: SfuTrackType.video,
        videoFit: fill ? VideoFit.cover : VideoFit.contain,
        placeholderBuilder: (_) => Center(
          child: _CircleAvatar(
            imageUrl: participant.image,
            name: participant.name.isNotEmpty
                ? participant.name
                : participant.userId,
            size: 110,
          ),
        ),
      ),
    );
  }
}

class _SelfViewTile extends StatelessWidget {
  final Call call;
  final CallParticipantState participant;
  const _SelfViewTile({required this.call, required this.participant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: StreamVideoRenderer(
          call: call,
          participant: participant,
          videoTrackType: SfuTrackType.video,
          videoFit: VideoFit.cover,
        ),
      ),
    );
  }
}
