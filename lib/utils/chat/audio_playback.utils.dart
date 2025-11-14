import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/message_model.dart';
import '../../services/media_cache_service.dart';
import '../../db/repositories/messages_repository.dart';
import 'chat_helpers.dart';

/// Audio playback manager for chat messages
///
/// Manages audio playback state, progress tracking, animations, and duration estimation
/// for both DM and group chat screens.
class AudioPlaybackManager {
  // Audio player instance
  late FlutterSoundPlayer _audioPlayer;

  // State management
  final Map<String, bool> _playingAudios = {};
  final Map<String, Duration> _audioDurations = {};
  final Map<String, Duration> _audioPositions = {};
  String? _currentPlayingAudioKey;

  // Progress tracking
  StreamSubscription? _audioProgressSubscription;
  Timer? _audioProgressTimer;
  DateTime? _audioStartTime;
  Duration _customPosition = Duration.zero;

  // Animation controllers
  final Map<String, AnimationController> _audioAnimationControllers = {};
  final Map<String, Animation<double>> _audioAnimations = {};

  // Dependencies
  final TickerProvider _vsync;
  final bool Function() _mounted;
  final VoidCallback _setState;
  final Function(String)? _showErrorDialog;
  final MediaCacheService? _mediaCacheService;
  final MessagesRepository? _messagesRepo;
  final List<MessageModel>? _messages;

  // Callbacks
  final void Function(String audioKey, Duration duration, Duration position)?
  _onProgressUpdate;

  AudioPlaybackManager({
    required TickerProvider vsync,
    required bool Function() mounted,
    required VoidCallback setState,
    Function(String)? showErrorDialog,
    MediaCacheService? mediaCacheService,
    MessagesRepository? messagesRepo,
    List<MessageModel>? messages,
    void Function(String audioKey, Duration duration, Duration position)?
    onProgressUpdate,
  }) : _vsync = vsync,
       _mounted = mounted,
       _setState = setState,
       _showErrorDialog = showErrorDialog,
       _mediaCacheService = mediaCacheService,
       _messagesRepo = messagesRepo,
       _messages = messages,
       _onProgressUpdate = onProgressUpdate {
    _audioPlayer = FlutterSoundPlayer();
  }

  /// Initialize the audio player
  Future<void> initialize() async {
    try {
      // Ensure player is closed first
      if (!_audioPlayer.isStopped) {
        await _audioPlayer.closePlayer();
      }

      await _audioPlayer.openPlayer();

      // Cancel existing subscription if any
      await _audioProgressSubscription?.cancel();

      // Set up onProgress listener as primary method
      _audioProgressSubscription = _audioPlayer.onProgress!.listen(
        (event) {
          if (_mounted() && _currentPlayingAudioKey != null) {
            final audioKey = _currentPlayingAudioKey!;
            if (_playingAudios[audioKey] ?? false) {
              _setState();
              _audioDurations[audioKey] = event.duration;
              _audioPositions[audioKey] = event.position;

              // Call progress update callback if provided
              _onProgressUpdate?.call(audioKey, event.duration, event.position);

              debugPrint(
                '🎵 OnProgress Stream: ${event.position.inSeconds}s / ${event.duration.inSeconds}s for $audioKey',
              );
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Audio progress stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Error initializing audio player: $e');
    }
  }

  /// Toggle audio playback (play/pause)
  Future<void> togglePlayback(
    String audioKey,
    String audioUrl, {
    void Function(String)? onError,
  }) async {
    try {
      // Ensure audio player is initialized
      if (_audioPlayer.isStopped) {
        await initialize();
      }

      final isCurrentlyPlaying = _playingAudios[audioKey] ?? false;

      if (isCurrentlyPlaying) {
        // Stop playback
        await _audioPlayer.stopPlayer();

        // Stop animation
        final controller = _audioAnimationControllers[audioKey];
        controller?.stop();

        // Stop progress timer and save current position
        _stopProgressTimer();

        _setState();
        _playingAudios[audioKey] = false;
        _currentPlayingAudioKey = null;
        // Keep the current position when paused
      } else {
        // Stop any currently playing audio
        _stopProgressTimer();
        for (final key in _playingAudios.keys) {
          _playingAudios[key] = false;
        }

        // Only reset position if this is a fresh start (not resume)
        final currentPosition = _audioPositions[audioKey] ?? Duration.zero;
        final currentDuration = _audioDurations[audioKey] ?? Duration.zero;

        // If we're at the end, start from beginning; otherwise resume from current position
        if (currentPosition.inMilliseconds >=
            currentDuration.inMilliseconds - 100) {
          _setState();
          _audioPositions[audioKey] = Duration.zero;
        }

        _setState();
        _playingAudios[audioKey] = true;
        _currentPlayingAudioKey = audioKey;

        // Start animation
        final controller = _getAnimationController(audioKey);
        controller.repeat(reverse: true);

        // Get local cached path or use remote URL
        String playbackUrl = audioUrl;

        if (_messages != null &&
            _mediaCacheService != null &&
            _messagesRepo != null) {
          // Extract message ID from audioKey (format: messageId_url)
          final messageId = int.tryParse(audioKey.split('_').first);

          if (messageId != null) {
            try {
              final message = _messages.firstWhere(
                (msg) => msg.id == messageId,
                orElse: () => _messages.first,
              );

              // Try to use local cached file
              playbackUrl = await ChatHelpers.getMediaPath(
                url: audioUrl,
                localPath: message.localMediaPath,
                mediaCacheService: _mediaCacheService,
              );

              // If using remote URL and not cached yet, cache it in background
              if (playbackUrl == audioUrl && message.localMediaPath == null) {
                ChatHelpers.cacheMediaForMessage(
                  url: audioUrl,
                  messageId: messageId,
                  messagesRepo: _messagesRepo,
                  mediaCacheService: _mediaCacheService,
                );
              }
            } catch (e) {
              debugPrint('⚠️ Error finding message for audio: $e');
            }
          }
        }

        // Start new playback
        await _audioPlayer.startPlayer(
          fromURI: playbackUrl,
          whenFinished: () {
            if (_mounted()) {
              // Stop animation
              final controller = _audioAnimationControllers[audioKey];
              controller?.stop();

              // Stop progress timer
              _stopProgressTimer();

              _setState();
              _playingAudios[audioKey] = false;
              // Keep position at duration when finished so we show total duration
              final duration = _audioDurations[audioKey] ?? Duration.zero;
              _audioPositions[audioKey] = duration;
              _currentPlayingAudioKey = null;
            }
          },
        );

        // Verify player is actually playing
        await Future.delayed(const Duration(milliseconds: 100));

        // Start progress timer as fallback
        _startProgressTimer(audioKey);

        debugPrint('🔊 Started audio playback for: $audioKey');
      }
    } catch (e) {
      debugPrint('❌ Error toggling audio playback: $e');
      if (e.toString().contains('has not been initialized')) {
        try {
          await _audioPlayer.openPlayer();
          if (_showErrorDialog != null) {
            _showErrorDialog(
              'Audio player was not ready. Please try playing again.',
            );
          }
        } catch (initError) {
          if (_showErrorDialog != null) {
            _showErrorDialog(
              'Failed to initialize audio player. Please restart the app.',
            );
          }
        }
      } else {
        if (onError != null) {
          onError(e.toString());
        } else if (_showErrorDialog != null) {
          _showErrorDialog('Failed to play audio. Please try again.');
        }
      }
    }
  }

  /// Start progress tracking timer
  void _startProgressTimer(String audioKey) {
    _audioProgressTimer?.cancel();

    // Get current position for resume functionality
    final currentPosition = _audioPositions[audioKey] ?? Duration.zero;

    // Adjust start time to account for current position (for resume)
    _audioStartTime = DateTime.now().subtract(currentPosition);
    _customPosition = currentPosition;

    _audioProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (!_mounted() ||
          _currentPlayingAudioKey != audioKey ||
          !(_playingAudios[audioKey] ?? false)) {
        timer.cancel();
        _audioStartTime = null;
        return;
      }

      try {
        if (_audioPlayer.isPlaying && _audioStartTime != null) {
          // Calculate custom position based on elapsed time
          final elapsed = DateTime.now().difference(_audioStartTime!);
          _customPosition = elapsed;

          // Get duration from getProgress (this part works)
          final progress = await _audioPlayer.getProgress();
          final duration = progress['duration'] ?? Duration.zero;

          if (_mounted() && duration.inMilliseconds > 0) {
            // Don't let position exceed duration
            final clampedPosition = Duration(
              milliseconds: _customPosition.inMilliseconds.clamp(
                0,
                duration.inMilliseconds,
              ),
            );

            _setState();
            _audioDurations[audioKey] = duration;
            _audioPositions[audioKey] = clampedPosition;

            // Call progress update callback if provided
            _onProgressUpdate?.call(audioKey, duration, clampedPosition);
          }
        } else {
          debugPrint('⚠️ Player not playing - stopping timer');
          timer.cancel();
          _audioStartTime = null;
        }
      } catch (e) {
        debugPrint('❌ Error in custom progress tracking: $e');
        timer.cancel();
      }
    });
  }

  /// Stop progress tracking timer
  void _stopProgressTimer() {
    _audioProgressTimer?.cancel();
    _audioProgressTimer = null;
    _audioStartTime = null;
    _customPosition = Duration.zero;
  }

  /// Estimate audio duration from file size
  void estimateDuration(String audioKey, int? fileSize) {
    // Skip if we already have duration
    if (_audioDurations[audioKey] != null &&
        _audioDurations[audioKey]!.inMilliseconds > 0) {
      return;
    }

    if (fileSize != null && fileSize > 0) {
      // Rough estimation: M4A files are typically 1MB per minute at 128kbps
      // This is just a rough estimate for display purposes
      final estimatedSeconds = (fileSize / (128 * 1024 / 8))
          .round(); // bytes per second at 128kbps
      final estimatedDuration = Duration(
        seconds: estimatedSeconds.clamp(1, 3600),
      ); // min 1s, max 1 hour

      _setState();
      _audioDurations[audioKey] = estimatedDuration;
    }
  }

  /// Get or create animation controller for audio key
  AnimationController _getAnimationController(String audioKey) {
    if (!_audioAnimationControllers.containsKey(audioKey)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: _vsync,
      );

      final animation = Tween<double>(
        begin: 0.5,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      _audioAnimationControllers[audioKey] = controller;
      _audioAnimations[audioKey] = animation;
    }
    return _audioAnimationControllers[audioKey]!;
  }

  /// Get animation for audio key
  Animation<double>? getAnimation(String audioKey) {
    return _audioAnimations[audioKey];
  }

  /// Format duration as MM:SS
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  // Getters for state
  bool isPlaying(String audioKey) => _playingAudios[audioKey] ?? false;
  Duration? getDuration(String audioKey) => _audioDurations[audioKey];
  Duration? getPosition(String audioKey) => _audioPositions[audioKey];
  String? get currentPlayingAudioKey => _currentPlayingAudioKey;

  /// Dispose all resources
  Future<void> dispose() async {
    // Stop any playing audio
    if (_currentPlayingAudioKey != null) {
      try {
        await _audioPlayer.stopPlayer();
      } catch (e) {
        debugPrint('Warning: Error stopping audio player during dispose: $e');
      }
    }

    // Cancel subscriptions and timers
    await _audioProgressSubscription?.cancel();
    _stopProgressTimer();

    // Close audio player
    try {
      if (_audioPlayer.isPlaying) {
        await _audioPlayer.stopPlayer();
      }
      await _audioPlayer.closePlayer();
    } catch (e) {
      debugPrint('Warning: Error closing audio player during dispose: $e');
    }

    // Dispose animation controllers
    for (final controller in _audioAnimationControllers.values) {
      controller.dispose();
    }
    _audioAnimationControllers.clear();
    _audioAnimations.clear();

    // Clear state
    _playingAudios.clear();
    _audioDurations.clear();
    _audioPositions.clear();
    _currentPlayingAudioKey = null;
  }
}

/// Voice recording manager for chat messages
///
/// Manages voice recording state, timer, animations, and file handling
/// for both DM and group chat screens.
class VoiceRecordingManager {
  // Recorder instance
  late FlutterSoundRecorder _recorder;

  // State management
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // Dependencies
  final bool Function() _mounted;
  final VoidCallback _setState;
  final Function(String)? _showErrorDialog;
  final BuildContext? _context;
  final AnimationController _voiceModalAnimationController;
  final AnimationController _zigzagAnimationController;
  final StreamController<Duration> _timerStreamController;
  final String _filePrefix; // "voice_note_" or "group_voice_note_"

  VoiceRecordingManager({
    required bool Function() mounted,
    required VoidCallback setState,
    Function(String)? showErrorDialog,
    BuildContext? context,
    required AnimationController voiceModalAnimationController,
    required AnimationController zigzagAnimationController,
    required StreamController<Duration> timerStreamController,
    String filePrefix = 'voice_note_',
  }) : _mounted = mounted,
       _setState = setState,
       _showErrorDialog = showErrorDialog,
       _context = context,
       _voiceModalAnimationController = voiceModalAnimationController,
       _zigzagAnimationController = zigzagAnimationController,
       _timerStreamController = timerStreamController,
       _filePrefix = filePrefix {
    _recorder = FlutterSoundRecorder();
  }

  /// Check and request microphone permission
  Future<void> checkAndRequestMicrophonePermission() async {
    final micStatus = await Permission.microphone.status;
    if (micStatus.isGranted) {
      return;
    }
    if (micStatus.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    await Permission.microphone.request();
  }

  /// Start voice recording
  Future<void> startRecording() async {
    try {
      // Check microphone permission first
      await checkAndRequestMicrophonePermission();
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        return;
      }

      // Initialize recorder if not already done
      if (_recorder.isStopped) {
        await _recorder.openRecorder();
      }

      // Get temporary directory for recording
      final Directory tempDir = await getTemporaryDirectory();
      final String recordingPath =
          '${tempDir.path}/${_filePrefix}${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording with AAC MP4 format (most widely supported)
      await _recorder.startRecorder(
        toFile: recordingPath,
        codec: Codec.aacMP4,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1, // Mono recording for smaller file size
      );

      _setState();
      _isRecording = true;
      _recordingPath = recordingPath;
      _recordingDuration = Duration.zero;

      // Initialize timer stream
      _timerStreamController.add(_recordingDuration);

      // Start animation
      _voiceModalAnimationController.forward();
      _zigzagAnimationController.repeat();

      // Start timer for recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_mounted()) {
          _recordingDuration = Duration(seconds: timer.tick);
          _setState();
          // Emit timer update to stream for modal
          _timerStreamController.add(_recordingDuration);
        }
      });
    } catch (e) {
      debugPrint('❌ Error starting voice recording: $e');
      if (_showErrorDialog != null) {
        _showErrorDialog('Failed to start recording. Please try again.');
      }
    }
  }

  /// Stop voice recording
  Future<void> stopRecording() async {
    try {
      if (!_isRecording) {
        return;
      }

      // Check minimum recording duration (at least 1 second)
      if (_recordingDuration.inSeconds < 1) {
        if (_showErrorDialog != null) {
          _showErrorDialog(
            'Recording is too short. Please record for at least 1 second.',
          );
        }
        return;
      }
      // Add a small delay to ensure audio is captured
      await Future.delayed(const Duration(milliseconds: 100));

      final recordingPath = await _recorder.stopRecorder();
      _recordingTimer?.cancel();
      _zigzagAnimationController.stop();
      // Wait a moment for file to be written completely
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify the file was created and has content
      if (recordingPath != null) {
        final file = File(recordingPath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;

        // For M4A files, minimum size should be much larger than 44 bytes
        if (!exists || size < 1000) {
          if (_showErrorDialog != null) {
            _showErrorDialog(
              'Recording failed - no audio was captured. Please check microphone permissions and try again.',
            );
          }
          return;
        }
      } else {
        if (_showErrorDialog != null) {
          _showErrorDialog(
            'Recording failed - no file path returned. Please try again.',
          );
        }
        return;
      }

      _setState();
      _isRecording = false;
      _recordingPath = recordingPath;
    } catch (e) {
      if (_showErrorDialog != null) {
        _showErrorDialog(
          'Failed to stop recording. Please try again. Error: $e',
        );
      }
    }
  }

  /// Cancel voice recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
        _zigzagAnimationController.stop();
      }

      // Cancel and reset timer
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _voiceModalAnimationController.reverse();

      // Delete the recording file if it exists
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Reset all recording state including timer
      _recordingDuration = Duration.zero; // Reset timer to 0:00
      _timerStreamController.add(_recordingDuration); // Emit reset to stream

      if (_mounted()) {
        _setState();
        _isRecording = false;
        _recordingPath = null;
      }

      if (_context != null && _context.mounted) {
        Navigator.of(_context).pop();
      }
    } catch (e) {
      debugPrint('❌ Error cancelling voice recording: $e');
    }
  }

  // Getters for state
  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;
  Duration get recordingDuration => _recordingDuration;

  /// Stop recording if still recording (for use in send method)
  Future<String?> stopIfRecording() async {
    if (_isRecording) {
      await stopRecording();
    }
    return _recordingPath;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      await _recorder.closeRecorder();
    } catch (e) {
      debugPrint('Warning: Error closing recorder during dispose: $e');
    }
    _isRecording = false;
    _recordingPath = null;
    _recordingDuration = Duration.zero;
  }
}
