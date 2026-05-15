import 'dart:async';
import 'dart:ui' as ui;

import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/community.model.dart';
import '../../models/group.model.dart';
import '../../providers/theme-color.provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessageInputContainer extends ConsumerStatefulWidget {
  final TextEditingController messageController;
  final ValueNotifier<bool> isOtherTypingNotifier;
  final Widget? typingIndicator;
  final bool isReplying;
  final bool isSending;
  final MessageModel? replyToMessageData;
  final String? currentUserId;
  final Function(MessageType)? onSendMessage;
  final VoidCallback? onSendVoiceNote;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final VoidCallback? onPickContact;
  final ValueChanged<String>? onTyping;
  final VoidCallback? onCancelReply;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  // For community group restrictions
  final bool isCommunityGroup;
  final CommunityGroupMetadata? communityGroupMetadata;

  // For DM - to determine if replied message is mine
  final DmModel? dm;
  final GroupModel? group;

  // Message recommendations widget (shown between typing indicator and message input)
  final Widget? recommendations;

  // ── Inline (WhatsApp-style) voice recording hooks ──────────────────
  // When all four are provided, the mic button uses long-press inline
  // recording instead of opening a separate modal.
  /// Begin a recording. Returns true if recording actually started
  /// (mic permission granted and recorder armed). Returning false
  /// reverts the UI to idle without entering the recording state.
  final Future<bool> Function()? onStartInlineRecording;

  /// Stop the current recording and return the captured file metadata.
  /// Returning null means the recording was too short / empty / failed
  /// (cleanup of the file is the implementor's responsibility); the UI
  /// will fall back to idle.
  final Future<({String path, int sizeBytes, Duration duration})?> Function()?
  onStopInlineRecording;

  /// Cancel an in-progress recording (file is deleted by the implementor).
  final Future<void> Function()? onCancelInlineRecording;

  /// Send a previously-stopped recording at the given file path.
  final Future<void> Function(String path)? onSendInlineRecording;

  /// Discard a previously-stopped recording at the given file path
  /// (used when the user taps the trash button in preview state).
  final Future<void> Function(String path)? onDiscardInlineRecording;

  /// Stream of recording-duration ticks while recording is in progress.
  /// Used to update the live timer above the input.
  final Stream<Duration>? inlineRecordingTimerStream;

  const MessageInputContainer({
    super.key,
    required this.messageController,
    required this.isOtherTypingNotifier,
    this.typingIndicator,
    required this.isReplying,
    required this.isSending,
    this.replyToMessageData,
    this.currentUserId,
    this.onSendMessage,
    this.onSendVoiceNote,
    this.onPickGallery,
    this.onPickCamera,
    this.onPickDocument,
    this.onPickContact,
    this.onTyping,
    this.onCancelReply,
    this.focusNode,
    this.onFocusChange,
    this.isCommunityGroup = false,
    this.communityGroupMetadata,
    this.dm,
    this.group,
    this.recommendations,
    this.onStartInlineRecording,
    this.onStopInlineRecording,
    this.onCancelInlineRecording,
    this.onSendInlineRecording,
    this.onDiscardInlineRecording,
    this.inlineRecordingTimerStream,
  });

  @override
  ConsumerState<MessageInputContainer> createState() =>
      _MessageInputContainerState();
}

/// Phases of the inline (WhatsApp-style) voice recorder.
enum _RecPhase {
  /// No active recording — normal input visible.
  idle,

  /// Finger held down on mic; live timer + slide-to-cancel hint shown.
  recording,

  /// Recording stopped, awaiting user choice (trash / send).
  preview,
}

/// Horizontal drag (in logical pixels) past which a release cancels
/// the recording instead of entering preview.
const double _kSlideToCancelThreshold = 80.0;

class _MessageInputContainerState extends ConsumerState<MessageInputContainer>
    with TickerProviderStateMixin {
  late final AnimationController _replyAnim;
  late final Animation<double> _replyAnimation;

  late final AnimationController _attachAnim;
  late final Animation<double> _attachAnimation;
  bool _attachmentMenuVisible = false;

  bool _showEmojiPanel = false;

  // Keeps the last reply data alive so the exit animation has content to show.
  MessageModel? _lastReplyData;

  // ── Inline voice-recording state ───────────────────────────────────
  _RecPhase _recPhase = _RecPhase.idle;

  /// Drives the entry/exit of the recording overlay (blur + slide-up).
  late final AnimationController _recOverlayAnim;
  late final Animation<double> _recOverlayAnimation;

  /// Pulses the red dot while recording.
  late final AnimationController _recPulseAnim;

  /// Crossfade between recording-state body and preview-state body
  /// inside the overlay.
  late final AnimationController _recPhaseAnim;

  /// Mic button "lift" while finger is held.
  late final AnimationController _micLiftAnim;

  /// Horizontal drag offset while in recording phase (negative = left).
  double _recDragX = 0.0;

  /// True once we have crossed the slide-to-cancel threshold and are
  /// committed to a cancel on release. Latched so brief jitter back
  /// across the line does not flap the hint state.
  bool _willCancelOnRelease = false;

  /// Latest tick from the recording timer stream (live duration).
  Duration _recDuration = Duration.zero;
  StreamSubscription<Duration>? _recTimerSub;

  /// Captured metadata after stop, used in preview phase.
  String? _previewPath;
  int? _previewSizeBytes;
  Duration _previewDuration = Duration.zero;

  /// True while we are awaiting an async start/stop call so we don't
  /// double-fire from rapid gestures.
  bool _recBusy = false;

  @override
  void initState() {
    super.initState();
    _replyAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _replyAnimation = CurvedAnimation(
      parent: _replyAnim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _attachAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _attachAnimation = CurvedAnimation(
      parent: _attachAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    if (widget.isReplying && widget.replyToMessageData != null) {
      _lastReplyData = widget.replyToMessageData;
      _replyAnim.value = 1.0;
    }

    _recOverlayAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _recOverlayAnimation = CurvedAnimation(
      parent: _recOverlayAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _recPulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _recPhaseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 0.0,
    );

    _micLiftAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 140),
    );
  }

  void _toggleAttachmentMenu() {
    if (_attachmentMenuVisible) {
      _closeAttachmentMenu();
    } else {
      _openAttachmentMenu();
    }
  }

  void _openAttachmentMenu() {
    // If the emoji panel is visible, close it so they don't stack.
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
    }
    setState(() => _attachmentMenuVisible = true);
    _attachAnim.forward();
  }

  void _toggleEmojiPanel() {
    if (_showEmojiPanel) {
      // Currently showing emoji → switch back to the system keyboard
      setState(() => _showEmojiPanel = false);
      widget.focusNode?.requestFocus();
    } else {
      // Currently showing keyboard (or nothing) → swap to emoji
      // The keyboard is what we DO want to dismiss here — it's the whole
      // point of "switch to emoji mode". This is intentional and only
      // happens for the emoji button, not the attachment button.
      widget.focusNode?.unfocus();
      // Close attachment menu if open so the bottom area stays uncluttered.
      if (_attachmentMenuVisible) {
        _closeAttachmentMenu();
      }
      setState(() => _showEmojiPanel = true);
    }
  }

  void _insertEmoji(String emoji) {
    final controller = widget.messageController;
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final newText = text.replaceRange(start, end, emoji);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    if (widget.onTyping != null) widget.onTyping!(newText);
  }

  void _emojiBackspace() {
    final controller = widget.messageController;
    final text = controller.text;
    final sel = controller.selection;
    if (text.isEmpty) return;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    if (start == end && start == 0) return;
    final removeStart = start == end ? start - 1 : start;
    final newText = text.replaceRange(removeStart, end, '');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: removeStart),
    );
    if (widget.onTyping != null) widget.onTyping!(newText);
  }

  void _closeAttachmentMenu() {
    _attachAnim.reverse().whenComplete(() {
      if (mounted) setState(() => _attachmentMenuVisible = false);
    });
  }

  void _onAttachmentOption(VoidCallback? callback) {
    _closeAttachmentMenu();
    if (callback == null) return;
    // Defer the action until the close animation has had a moment to play.
    Future.delayed(const Duration(milliseconds: 80), callback);
  }

  @override
  void didUpdateWidget(MessageInputContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasShowing =
        oldWidget.isReplying && oldWidget.replyToMessageData != null;
    final isShowing = widget.isReplying && widget.replyToMessageData != null;

    if (!wasShowing && isShowing) {
      // Opened — update data then animate in
      _lastReplyData = widget.replyToMessageData;
      _replyAnim.forward();
    } else if (wasShowing && !isShowing) {
      // Closed — animate out; keep _lastReplyData until animation finishes
      _replyAnim.reverse().whenComplete(() {
        if (mounted) setState(() => _lastReplyData = null);
      });
    } else if (isShowing &&
        widget.replyToMessageData != oldWidget.replyToMessageData) {
      // Changed reply target — swap content, no animation change needed
      setState(() => _lastReplyData = widget.replyToMessageData);
    }
  }

  @override
  void dispose() {
    _replyAnim.dispose();
    _attachAnim.dispose();
    // If we're being torn down mid-recording, ask the host to clean up
    // the recorder (file delete, recorder close). Fire-and-forget — we
    // can't await in dispose.
    if (_recPhase == _RecPhase.recording &&
        widget.onCancelInlineRecording != null) {
      widget.onCancelInlineRecording!();
    } else if (_recPhase == _RecPhase.preview &&
        _previewPath != null &&
        widget.onDiscardInlineRecording != null) {
      widget.onDiscardInlineRecording!(_previewPath!);
    }
    _recTimerSub?.cancel();
    _recOverlayAnim.dispose();
    _recPulseAnim.dispose();
    _recPhaseAnim.dispose();
    _micLiftAnim.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  //  Inline voice-recording: actions
  // ─────────────────────────────────────────────────────────────────

  bool get _canUseInlineRecording =>
      widget.onStartInlineRecording != null &&
      widget.onStopInlineRecording != null &&
      widget.onCancelInlineRecording != null &&
      widget.onSendInlineRecording != null;

  void _subscribeRecordingTimer() {
    _recTimerSub?.cancel();
    final stream = widget.inlineRecordingTimerStream;
    if (stream == null) return;
    _recTimerSub = stream.listen((d) {
      if (!mounted) return;
      if (_recPhase != _RecPhase.recording) return;
      setState(() => _recDuration = d);
    });
  }

  Future<void> _onMicLongPressStart(LongPressStartDetails _) async {
    if (!_canUseInlineRecording) return;
    if (_recBusy || _recPhase != _RecPhase.idle) return;

    _recBusy = true;
    // Dismiss any open panels so the recorder gets the focus visually.
    if (_attachmentMenuVisible) _closeAttachmentMenu();
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
    }

    // Optimistic UI: lift the mic immediately, even before perm dialog.
    _micLiftAnim.forward();
    HapticFeedback.lightImpact();

    final started = await widget.onStartInlineRecording!();
    if (!mounted) {
      _recBusy = false;
      return;
    }
    if (!started) {
      _micLiftAnim.reverse();
      _recBusy = false;
      return;
    }

    setState(() {
      _recPhase = _RecPhase.recording;
      _recDuration = Duration.zero;
      _recDragX = 0.0;
      _willCancelOnRelease = false;
    });
    _recPhaseAnim.value = 0.0; // recording side visible
    _recOverlayAnim.forward();
    _recPulseAnim.repeat(reverse: true);
    _subscribeRecordingTimer();
    _recBusy = false;
  }

  void _onMicLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_recPhase != _RecPhase.recording) return;
    // Only left-drag counts. Clamp at 0 (no rightward drag has effect).
    final dx = details.localOffsetFromOrigin.dx;
    final clamped = dx > 0 ? 0.0 : dx;
    setState(() => _recDragX = clamped);

    final pastThreshold = clamped.abs() >= _kSlideToCancelThreshold;
    if (pastThreshold && !_willCancelOnRelease) {
      _willCancelOnRelease = true;
      HapticFeedback.mediumImpact();
    } else if (!pastThreshold && _willCancelOnRelease) {
      _willCancelOnRelease = false;
    }
  }

  void _onMicLongPressEnd(LongPressEndDetails _) {
    _finishLongPress();
  }

  void _onMicLongPressCancel() {
    // Fired e.g. when another gesture wins. Treat as a normal release —
    // we don't want to leave the recorder running.
    _finishLongPress();
  }

  Future<void> _finishLongPress() async {
    if (_recPhase != _RecPhase.recording) {
      // Either the long-press never reached "recording" (perm denied,
      // start failed) or we're in some other phase. Reset mic lift.
      _micLiftAnim.reverse();
      return;
    }

    _micLiftAnim.reverse();
    final shouldCancel = _willCancelOnRelease;

    if (shouldCancel) {
      await _doCancelRecording();
      return;
    }

    if (_recBusy) return;
    _recBusy = true;
    final result = await widget.onStopInlineRecording!();
    if (!mounted) {
      _recBusy = false;
      return;
    }

    _recPulseAnim.stop();
    _recTimerSub?.cancel();
    _recTimerSub = null;

    if (result == null) {
      // Too short / empty — bail back to idle.
      setState(() {
        _recPhase = _RecPhase.idle;
        _recDuration = Duration.zero;
        _recDragX = 0.0;
        _willCancelOnRelease = false;
      });
      _recOverlayAnim.reverse();
      _showShortRecordingHint();
      _recBusy = false;
      return;
    }

    setState(() {
      _recPhase = _RecPhase.preview;
      _previewPath = result.path;
      _previewSizeBytes = result.sizeBytes;
      _previewDuration = result.duration;
      _recDragX = 0.0;
      _willCancelOnRelease = false;
    });
    _recPhaseAnim.forward(); // preview side
    HapticFeedback.selectionClick();
    _recBusy = false;
  }

  Future<void> _doCancelRecording() async {
    if (_recBusy) return;
    _recBusy = true;
    HapticFeedback.mediumImpact();

    _recPulseAnim.stop();
    _recTimerSub?.cancel();
    _recTimerSub = null;

    try {
      await widget.onCancelInlineRecording?.call();
    } catch (_) {
      // Swallow: cancellation is best-effort.
    }

    if (!mounted) {
      _recBusy = false;
      return;
    }
    setState(() {
      _recPhase = _RecPhase.idle;
      _recDuration = Duration.zero;
      _recDragX = 0.0;
      _willCancelOnRelease = false;
    });
    _recOverlayAnim.reverse();
    _recBusy = false;
  }

  Future<void> _onPreviewDelete() async {
    if (_recBusy) return;
    _recBusy = true;
    HapticFeedback.lightImpact();

    final path = _previewPath;
    if (path != null && widget.onDiscardInlineRecording != null) {
      try {
        await widget.onDiscardInlineRecording!(path);
      } catch (_) {}
    }

    if (!mounted) {
      _recBusy = false;
      return;
    }
    setState(() {
      _recPhase = _RecPhase.idle;
      _previewPath = null;
      _previewSizeBytes = null;
      _previewDuration = Duration.zero;
      _recDuration = Duration.zero;
    });
    _recPhaseAnim.reverse();
    _recOverlayAnim.reverse();
    _recBusy = false;
  }

  Future<void> _onPreviewSend() async {
    if (_recBusy) return;
    final path = _previewPath;
    if (path == null) return;
    _recBusy = true;
    HapticFeedback.selectionClick();

    final pathToSend = path;
    // Optimistically tear the overlay down so the UI feels snappy.
    setState(() {
      _recPhase = _RecPhase.idle;
      _previewPath = null;
      _previewSizeBytes = null;
      _previewDuration = Duration.zero;
      _recDuration = Duration.zero;
    });
    _recPhaseAnim.reverse();
    _recOverlayAnim.reverse();

    try {
      await widget.onSendInlineRecording?.call(pathToSend);
    } catch (_) {
      // Errors are surfaced via the host's showErrorDialog.
    }
    if (!mounted) return;
    _recBusy = false;
  }

  void _showShortRecordingHint() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Tap and hold to record audio'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1400),
      ),
    );
  }

  // For users who *tap* the mic instead of long-pressing. Surface a hint
  // rather than silently doing nothing.
  void _onMicTap() {
    if (!_canUseInlineRecording) {
      // Fall back to the legacy modal flow if the host hasn't wired up
      // inline recording. Preserves backward compatibility.
      widget.onSendVoiceNote?.call();
      return;
    }
    // _showShortRecordingHint();
  }

  String _formatDur(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final isCommunityGroupActive = _isCommunityGroupActive();
    final shouldDisableSending =
        widget.isCommunityGroup && !isCommunityGroupActive;

    return Column(
      children: [
        // Time restriction notice for community groups
        if (widget.isCommunityGroup && !isCommunityGroupActive)
          _buildTimeRestrictionNotice(),

        // Typing indicator
        ValueListenableBuilder<bool>(
          valueListenable: widget.isOtherTypingNotifier,
          builder: (context, isOtherTyping, child) {
            if (isOtherTyping && widget.typingIndicator != null) {
              return widget.typingIndicator!;
            }
            return const SizedBox.shrink();
          },
        ),

        // Message Recommendations
        if (widget.recommendations != null) widget.recommendations!,

        // ── Attachment picker (sibling above the input pill so it tracks
        //     keyboard offset automatically) ──────────────────────────
        AnimatedBuilder(
          animation: _attachAnimation,
          builder: (context, child) {
            final v = _attachAnimation.value;
            if (v == 0.0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                heightFactor: v,
                child: Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1.0 - v) * 24),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: _attachmentMenuVisible
              ? _buildAttachmentMenu(themeColor)
              : null,
        ),

        // Reply container — always in the tree (no conditional) so the TextField
        // never shifts position and keyboard focus is preserved.
        // Slides in from bottom on open, slides back down on close.
        AnimatedBuilder(
          animation: _replyAnimation,
          builder: (context, child) {
            final v = _replyAnimation.value;
            if (v == 0.0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                heightFactor: v,
                child: FractionalTranslation(
                  translation: Offset(0.0, 1.0 - v),
                  child: child,
                ),
              ),
            );
          },
          child: _lastReplyData != null
              ? _buildReplyContainer(_lastReplyData!, themeColor)
              : const SizedBox.shrink(),
        ),

        // The input row is wrapped in a Stack so the inline voice-recorder
        // overlay can blur over the input pill while leaving the
        // mic/send button visually anchored on the right.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Input pill: emoji • text • attachment ───────────
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: shouldDisableSending
                            ? Colors.grey[200]
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Emoji ↔ keyboard toggle
                          IconButton(
                            icon: Icon(
                              _showEmojiPanel
                                  ? Icons.keyboard_outlined
                                  : Icons.sentiment_satisfied_alt_outlined,
                              color: shouldDisableSending
                                  ? Colors.grey[400]
                                  : (_showEmojiPanel
                                        ? themeColor.primary
                                        : Colors.grey[600]),
                            ),
                            onPressed: shouldDisableSending
                                ? null
                                : _toggleEmojiPanel,
                            splashRadius: 22,
                          ),
                          Expanded(
                            child: TextField(
                              controller: widget.messageController,
                              focusNode: widget.focusNode,
                              enabled: !shouldDisableSending,
                              decoration: InputDecoration(
                                hintText: shouldDisableSending
                                    ? 'Messaging is disabled outside active hours'
                                    : 'Message',
                                hintStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF1F2329),
                              ),
                              maxLines: 6,
                              minLines: 1,
                              textInputAction: TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: shouldDisableSending
                                  ? null
                                  : (value) {
                                      if (widget.onTyping != null) {
                                        widget.onTyping!(value);
                                      }
                                      if (widget.onFocusChange != null) {
                                        widget.onFocusChange!(
                                          widget.focusNode?.hasFocus ?? false,
                                        );
                                      }
                                    },
                              onTap: () {
                                if (_showEmojiPanel) {
                                  setState(() => _showEmojiPanel = false);
                                }
                                if (widget.onFocusChange != null) {
                                  widget.onFocusChange!(true);
                                }
                              },
                            ),
                          ),
                          // Attachment (paperclip, slightly tilted like Telegram)
                          IconButton(
                            icon: Transform.rotate(
                              angle: -0.6,
                              child: Icon(
                                Icons.attach_file_rounded,
                                color: shouldDisableSending
                                    ? Colors.grey[400]
                                    : (_attachmentMenuVisible
                                          ? themeColor.primary
                                          : Colors.grey[700]),
                              ),
                            ),
                            onPressed: shouldDisableSending
                                ? null
                                : _toggleAttachmentMenu,
                            splashRadius: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── Send/mic anchor (placeholder for layout) ────────
                  // The actual button is rendered as a Positioned child
                  // *above* the recording overlay so that when the user
                  // slides it leftward (slide-to-cancel), it stays on
                  // top of the blurred overlay instead of disappearing
                  // beneath it.
                  const SizedBox(width: 48, height: 48),
                ],
              ),

              // ── Inline recording overlay (sits on top of the input
              //     pill but leaves the right-side mic anchor visible).
              if (_canUseInlineRecording)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _recPhase == _RecPhase.idle,
                    child: AnimatedBuilder(
                      animation: _recOverlayAnimation,
                      builder: (context, _) {
                        final v = _recOverlayAnimation.value;
                        if (v == 0.0) return const SizedBox.shrink();
                        return _buildRecordingOverlay(v, themeColor);
                      },
                    ),
                  ),
                ),

              // ── Send / mic button (always topmost so the slide-to-
              //     cancel translation isn't clipped by the overlay).
              Positioned(
                right: 0,
                bottom: 0,
                child: _buildSendOrMicButton(themeColor, shouldDisableSending),
              ),
            ],
          ),
        ),

        // ── Emoji panel (sits where the keyboard would be) ────────────
        if (_showEmojiPanel)
          SizedBox(
            height: 300,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) => _insertEmoji(emoji.emoji),
              onBackspacePressed: _emojiBackspace,
              config: Config(
                emojiViewConfig: const EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28,
                  backgroundColor: Colors.white,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: Colors.white,
                  buttonIconColor: Colors.grey[600]!,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: Colors.white,
                  iconColor: Colors.grey[400]!,
                  iconColorSelected: themeColor.primary,
                  indicatorColor: themeColor.primary,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Standalone right-side button. Shows:
  ///   • SEND when there is text
  ///   • MIC when there isn't (long-press to record inline)
  Widget _buildSendOrMicButton(themeColor, bool shouldDisableSending) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.messageController,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final disabled = shouldDisableSending || widget.isSending;

        // While in preview phase the right-side anchor turns into the
        // animated send button used by the recording overlay; we still
        // render a placeholder of the same size to preserve the row's
        // layout (no jumping when phase changes).
        if (_recPhase == _RecPhase.preview) {
          return _buildPreviewSendAnchor(themeColor);
        }

        // Drive the mic-lift while the user is holding the button down.
        return AnimatedBuilder(
          animation: _micLiftAnim,
          builder: (context, child) {
            final lift = _micLiftAnim.value; // 0..1
            final scale = 1.0 + 0.18 * lift;
            // Slight upward shift so the lift feels physical.
            final dy = -6.0 * lift;
            // Allow the mic to drift left while the user is dragging
            // toward the slide-to-cancel zone.
            final dx = _recPhase == _RecPhase.recording ? _recDragX : 0.0;

            // Drop shadow tint follows the recording-state color.
            final shadowColor =
                (_recPhase == _RecPhase.recording
                        ? Colors.red
                        : themeColor.primary)
                    .withAlpha(60 + (60 * lift).round());

            return Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 8 + 12 * lift,
                        offset: Offset(0, 2 + 4 * lift),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (hasText || disabled || !_canUseInlineRecording)
                  ? null
                  : _onMicLongPressStart,
              onLongPressMoveUpdate:
                  (hasText || disabled || !_canUseInlineRecording)
                  ? null
                  : _onMicLongPressMoveUpdate,
              onLongPressEnd: (hasText || disabled || !_canUseInlineRecording)
                  ? null
                  : _onMicLongPressEnd,
              onLongPressCancel:
                  (hasText || disabled || !_canUseInlineRecording)
                  ? null
                  : _onMicLongPressCancel,
              onTap: disabled
                  ? null
                  : (hasText
                        ? () => widget.onSendMessage!(MessageType.text)
                        : _onMicTap),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: disabled
                      ? Colors.grey[400]
                      : (_recPhase == _RecPhase.recording
                            ? Colors.red
                            : themeColor.primary),
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    hasText
                        ? Icons.send_rounded
                        : (_recPhase == _RecPhase.recording
                              ? Icons.mic
                              : Icons.mic_rounded),
                    key: ValueKey<String>(
                      hasText
                          ? 'send'
                          : (_recPhase == _RecPhase.recording
                                ? 'mic-rec'
                                : 'mic'),
                    ),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// In preview phase the right-side button doubles as the "send the
  /// recording" button. We render it on top of the overlay so it sits
  /// at the same anchor as the idle mic button.
  Widget _buildPreviewSendAnchor(themeColor) {
    return GestureDetector(
      onTap: _onPreviewSend,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: themeColor.primary,
          boxShadow: [
            BoxShadow(
              color: themeColor.primary.withAlpha(120),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  /// The blurred overlay that sits on top of the input pill while the
  /// user is recording or previewing a recording. Crossfades between
  /// the two phase bodies based on [_recPhaseAnim].
  Widget _buildRecordingOverlay(double t, themeColor) {
    // Reserve room on the right for the existing send/mic anchor so
    // it stays visible. 48 = button width, 8 = row gap.
    const rightAnchorReserve = 48.0 + 8.0;

    final sigma = 8.0 * t;
    final fade = t.clamp(0.0, 1.0);

    // Padding-right is applied OUTSIDE the BackdropFilter so the blur
    // does not bleed over the mic / send button on the right.
    return Padding(
      padding: const EdgeInsets.only(right: rightAnchorReserve),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Opacity(
            opacity: fade,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _recPhase == _RecPhase.recording
                      ? Colors.red.withAlpha(80)
                      : themeColor.primary.withAlpha(80),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _recPhaseAnim,
                builder: (context, _) {
                  final p = _recPhaseAnim.value; // 0 = recording, 1 = preview
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1.0 - p,
                        child: IgnorePointer(
                          ignoring: p > 0.5,
                          child: _buildRecordingPhaseBody(themeColor),
                        ),
                      ),
                      Opacity(
                        opacity: p,
                        child: IgnorePointer(
                          ignoring: p < 0.5,
                          child: _buildPreviewPhaseBody(themeColor),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingPhaseBody(themeColor) {
    // Fade the slide-to-cancel hint as the user drags toward cancel.
    final dragRatio = (_recDragX.abs() / _kSlideToCancelThreshold).clamp(
      0.0,
      1.0,
    );
    final hintOpacity = 1.0 - dragRatio;

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            // Pulsing red dot
            AnimatedBuilder(
              animation: _recPulseAnim,
              builder: (context, _) {
                final v = _recPulseAnim.value;
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(Colors.red.withAlpha(120), Colors.red, v),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha((102 * v).round()),
                        blurRadius: 8 * v,
                        spreadRadius: 2 * v,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              _formatDur(_recDuration),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2329),
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            // Slide-to-cancel hint
            Expanded(
              child: Opacity(
                opacity: hintOpacity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _willCancelOnRelease
                          ? 'Release to cancel'
                          : 'Slide to cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: _willCancelOnRelease
                            ? Colors.red
                            : Colors.grey[700],
                        fontWeight: _willCancelOnRelease
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPhaseBody(themeColor) {
    final size = _previewSizeBytes;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            // Trash button
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _onPreviewDelete,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withAlpha(20),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Audio chip indicator
            Icon(Icons.graphic_eq_rounded, size: 18, color: themeColor.primary),
            const SizedBox(width: 8),
            Text(
              _formatDur(_previewDuration),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2329),
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
            if (size != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatSize(size),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentMenu(themeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withAlpha(25),
          //     blurRadius: 10,
          //     offset: const Offset(0, 4),
          //   ),
          // ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AttachmentTile(
              icon: Icons.image_outlined,
              label: 'Gallery',
              color: const Color(0xFF3B82F6),
              onTap: () => _onAttachmentOption(widget.onPickGallery),
            ),
            _AttachmentTile(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              color: const Color(0xFFE0457B),
              onTap: () => _onAttachmentOption(widget.onPickCamera),
            ),
            _AttachmentTile(
              icon: Icons.description_outlined,
              label: 'Document',
              color: const Color(0xFF7C3AED),
              onTap: () => _onAttachmentOption(widget.onPickDocument),
            ),
            _AttachmentTile(
              icon: Icons.person_outline_rounded,
              label: 'Contact',
              color: const Color(0xFF22C55E),
              onTap: () => _onAttachmentOption(widget.onPickContact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyContainer(MessageModel replyMessage, themeColor) {
    final isRepliedMessageMine = replyMessage.senderId == widget.currentUserId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        // borderRadius: widget.dm != null
        //     ? const BorderRadius.only(topRight: Radius.circular(12))
        //     : const BorderRadius.only(
        //         topLeft: Radius.circular(12),
        //         topRight: Radius.circular(12),
        //       ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: themeColor.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: themeColor.primary),
                    const SizedBox(width: 4),
                    Text(
                      isRepliedMessageMine ? 'You' : replyMessage.senderName!,
                      style: TextStyle(
                        color: themeColor.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (replyMessage.body?.isNotEmpty ?? false)
                  Text(
                    replyMessage.body!.length > 50
                        ? '${replyMessage.body!.substring(0, 50)}...'
                        : replyMessage.body!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    '📎 media',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            icon: Icon(Icons.close, size: 20, color: themeColor.primary),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  bool _isCommunityGroupActive() {
    if (!widget.isCommunityGroup || widget.communityGroupMetadata == null) {
      return true;
    }

    final metadata = widget.communityGroupMetadata!;
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);

    for (final timeSlot in metadata.activeTimeSlots) {
      if (_isTimeInRange(currentTime, timeSlot.startTime, timeSlot.endTime)) {
        return true;
      }
    }

    return false;
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  Widget _buildTimeRestrictionNotice() {
    final metadata = widget.communityGroupMetadata;
    if (metadata == null || metadata.activeTimeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeTimeSlotsText = metadata.activeTimeSlots
        .map((slot) => slot.displayTime)
        .join(', ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.orange[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messaging restricted',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Active: $activeTimeSlotsText',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single labelled tile in the attachment picker grid.
class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(50),
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.black.withAlpha(18),
                //     blurRadius: 6,
                //     offset: const Offset(0, 2),
                //   ),
                // ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
