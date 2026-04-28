import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../models/message.model.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/voice-recording.widget.dart';
import '../../../utils/animations.utils.dart';
import '../../../utils/chat/audio-playback.utils.dart';

/// Voice-note recording shared by DM and group messaging screens. Owns the
/// modal animation controllers, the timer stream, and the
/// [VoiceRecordingManager]. Hosts plug in via [voiceFilePrefix] (and
/// optionally the modal's text/color knobs) and call
/// [initializeVoiceRecording] from `initState` and [disposeVoiceRecording]
/// from `dispose`.
mixin ChatVoiceRecordingMixin<T extends StatefulWidget>
    on State<T>, TickerProvider {
  late AnimationController voiceModalAnimationController;
  late AnimationController zigzagAnimationController;
  late Animation<double> voiceModalAnimation;
  late Animation<double> zigzagAnimation;
  final StreamController<Duration> timerStreamController =
      StreamController<Duration>.broadcast();
  late VoiceRecordingManager voiceRecordingManager;

  void safeSetState(VoidCallback fn);
  void showErrorDialog(String message);
  Future<void> sendMediaMessageToServer(File file, MessageType type);

  String get voiceFilePrefix;
  String get voiceRecordingTextPrefix => 'Recording';
  Color get voiceSendButtonColor => Colors.teal;

  void initializeVoiceRecording() {
    final result = initializeVoiceAnimations(this);
    voiceModalAnimationController = result.voiceModalController;
    zigzagAnimationController = result.zigzagController;
    voiceModalAnimation = result.voiceModalAnimation;
    zigzagAnimation = result.zigzagAnimation;

    voiceRecordingManager = VoiceRecordingManager(
      mounted: () => mounted,
      setState: () => safeSetState(() {}),
      showErrorDialog: showErrorDialog,
      context: context,
      voiceModalAnimationController: voiceModalAnimationController,
      zigzagAnimationController: zigzagAnimationController,
      timerStreamController: timerStreamController,
      filePrefix: voiceFilePrefix,
    );
  }

  void disposeVoiceRecording() {
    voiceRecordingManager.dispose();
    voiceModalAnimationController.dispose();
    zigzagAnimationController.dispose();
    timerStreamController.close();
  }

  void sendVoiceNote() async {
    final micStatus = await Permission.microphone.status;
    if (micStatus.isGranted) {
      showVoiceRecordingModal();
    } else {
      await checkAndRequestMicrophonePermission();
      final newStatus = await Permission.microphone.status;
      if (newStatus.isGranted) {
        showVoiceRecordingModal();
      }
    }
  }

  void showVoiceRecordingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              child: VoiceRecordingModal(
                onStartRecording: startRecording,
                onStopRecording: stopRecording,
                onCancelRecording: cancelRecording,
                onSendRecording: sendRecordedVoice,
                isRecording: voiceRecordingManager.isRecording,
                recordingDuration: voiceRecordingManager.recordingDuration,
                zigzagAnimation: zigzagAnimation,
                voiceModalAnimation: voiceModalAnimation,
                timerStream: timerStreamController.stream,
                recordingTextPrefix: voiceRecordingTextPrefix,
                sendButtonColor: voiceSendButtonColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> checkAndRequestMicrophonePermission() async {
    await voiceRecordingManager.checkAndRequestMicrophonePermission();
  }

  Future<void> startRecording() async {
    await voiceRecordingManager.startRecording();
  }

  Future<void> stopRecording() async {
    await voiceRecordingManager.stopRecording();
  }

  Future<void> cancelRecording() async {
    await voiceRecordingManager.cancelRecording();
  }

  Future<void> sendRecordedVoice({MessageModel? failedMessage}) async {
    try {
      File? voiceFile;

      if (failedMessage != null) {
        final attachments = failedMessage.attachments;
        final localPath = attachments?['local_path'] as String?;
        if (localPath == null || !File(localPath).existsSync()) {
          showErrorDialog('Original recording not found. Please record again.');
          return;
        }
        voiceFile = File(localPath);
      } else {
        final recordingPath = await voiceRecordingManager.stopIfRecording();
        if (recordingPath == null) {
          showErrorDialog('No recording found. Please try again.');
          return;
        }
        voiceFile = File(recordingPath);
        if (!await voiceFile.exists()) {
          showErrorDialog('Recording file not found. Please try again.');
          return;
        }
        final fileSize = await voiceFile.length();
        if (fileSize == 0) {
          showErrorDialog('Recording is empty. Please try recording again.');
          return;
        }
      }

      await stopRecording();

      if (mounted && failedMessage == null) {
        Navigator.of(context).pop();
      }

      await sendMediaMessageToServer(voiceFile, MessageType.audio);
    } catch (e) {
      showErrorDialog('Failed to send voice note. Please try again.');
    }
  }
}
