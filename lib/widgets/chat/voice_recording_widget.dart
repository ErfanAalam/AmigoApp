import 'package:flutter/material.dart';

/// Builds an animated waveform widget for audio playback
///
/// [isMyMessage] - Whether this is the current user's message (affects color)
/// [animation] - The animation controller for the waveform animation
Widget buildAnimatedWaveform(bool isMyMessage, Animation<double> animation) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(4, (index) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final delay = index * 0.2;
          final animValue = (animation.value + delay) % 1.0;
          final height = 4 + (animValue * 8);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 2,
            height: height,
            decoration: BoxDecoration(
              color: isMyMessage ? Colors.white70 : Colors.blue[600],
              borderRadius: BorderRadius.circular(1),
            ),
          );
        },
      );
    }),
  );
}

/// Voice Recording Modal widget for both DM and group chats
class VoiceRecordingModal extends StatefulWidget {
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendRecording;
  final bool isRecording;
  final Duration recordingDuration;
  final Animation<double> zigzagAnimation;
  final Animation<double> voiceModalAnimation;
  final Stream<Duration> timerStream;
  final String recordingTextPrefix;
  final Color sendButtonColor;

  const VoiceRecordingModal({
    super.key,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
    required this.isRecording,
    required this.recordingDuration,
    required this.zigzagAnimation,
    required this.voiceModalAnimation,
    required this.timerStream,
    this.recordingTextPrefix = 'Recording',
    this.sendButtonColor = Colors.teal,
  });

  @override
  State<VoiceRecordingModal> createState() => _VoiceRecordingModalState();
}

class _VoiceRecordingModalState extends State<VoiceRecordingModal> {
  @override
  void initState() {
    super.initState();
    // Auto-start recording when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStartRecording();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.voiceModalAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.voiceModalAnimation.value,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  // Microphone icon with pulse animation
                  AnimatedBuilder(
                    animation: widget.zigzagAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: widget.isRecording
                              ? Colors.red
                              : Colors.grey[300],
                          shape: BoxShape.circle,
                          boxShadow: widget.isRecording
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(
                                      0.3 * widget.zigzagAnimation.value,
                                    ),
                                    blurRadius:
                                        20 * widget.zigzagAnimation.value,
                                    spreadRadius:
                                        5 * widget.zigzagAnimation.value,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.mic,
                          color: widget.isRecording
                              ? Colors.white
                              : Colors.grey[600],
                          size: 20,
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 15),

                  // Recording info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (widget.isRecording) ...[
                              AnimatedBuilder(
                                animation: widget.zigzagAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(
                                        widget.zigzagAnimation.value,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            StreamBuilder<Duration>(
                              stream: widget.timerStream,
                              initialData: widget.recordingDuration,
                              builder: (context, snapshot) {
                                final currentDuration =
                                    snapshot.data ?? Duration.zero;
                                return Text(
                                  widget.isRecording
                                      ? '${widget.recordingTextPrefix} ${_formatDuration(currentDuration)}'
                                      : _formatDuration(currentDuration),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isRecording
                                        ? Colors.red
                                        : Colors.teal,
                                    letterSpacing: 0.5,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Control buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delete button
                      GestureDetector(
                        onTap: widget.onCancelRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Send/Stop button
                      GestureDetector(
                        onTap: widget.isRecording
                            ? widget.onStopRecording
                            : widget.onSendRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.isRecording
                                ? Colors.red.withOpacity(0.1)
                                : widget.sendButtonColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isRecording ? Icons.stop : Icons.send,
                            color: widget.isRecording
                                ? Colors.red
                                : widget.sendButtonColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
