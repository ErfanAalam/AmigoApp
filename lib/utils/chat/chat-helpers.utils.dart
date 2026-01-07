import 'dart:io' as io;
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/call/call.service.dart';
import '../../services/socket/websocket.service.dart';
import '../../ui/snackbar.dart';
import '../animations.utils.dart';

class ChatHelpers {
  static final MessageRepository messageRepo = MessageRepository();
  static final WebSocketService webSocketService = WebSocketService();
  static final ConversationRepository conversationRepo =
      ConversationRepository();
  // Check if a message is a media message (image, video, audio, document)
  static bool isMediaMessage(MessageModel message) {
    // Check type first - new message types
    final type = message.type.value;
    if (type == 'image' ||
        type == 'video' ||
        type == 'audio' ||
        type == 'document') {
      return true;
    }

    // Backward compatibility for old types
    if (type == 'attachment' ||
        type == 'docs' ||
        type == 'audios' ||
        type == 'media') {
      return true;
    }

    // Also check attachments category as fallback
    if (message.attachments != null) {
      final attachmentData = message.attachments as Map<String, dynamic>;
      final category = attachmentData['category'] as String?;
      if (category != null) {
        final categoryLower = category.toLowerCase();
        return categoryLower == 'images' ||
            categoryLower == 'videos' ||
            categoryLower == 'docs' ||
            categoryLower == 'audios';
      }
    }

    return false;
  }

  /// Scroll to bottom of message list
  ///
  /// Handles scrolling to the bottom of a reversed ListView (where 0 is the bottom).
  /// Takes callbacks to update state after scrolling completes.
  static Future<void> scrollToBottom({
    required ScrollController scrollController,
    required VoidCallback onScrollComplete,
    bool mounted = true,
  }) async {
    if (!scrollController.hasClients) return;

    await Future.delayed(const Duration(milliseconds: 100));

    if (!scrollController.hasClients) return;

    await scrollController.animateTo(
      0, // Since we're using reverse: true, 0 is the bottom
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    // Call the callback to update state
    if (mounted) {
      onScrollComplete();
    }
  }

  /// Convert UTC datetime string to device's local timezone
  /// This automatically adapts to the user's timezone regardless of their location
  static DateTime convertToLocalTime(String dateTimeString) {
    try {
      // Parse the datetime - handle both UTC and local formats
      DateTime parsedDateTime;
      if (dateTimeString.endsWith('Z')) {
        // Already UTC format
        parsedDateTime = DateTime.parse(dateTimeString).toUtc();
      } else if (dateTimeString.contains('+') || dateTimeString.contains('T')) {
        // ISO format with timezone or T separator
        parsedDateTime = DateTime.parse(dateTimeString).toUtc();
      } else {
        // Assume local format, convert to UTC first
        parsedDateTime = DateTime.parse(dateTimeString).toUtc();
      }

      // Convert to device's local timezone automatically
      // This will show the correct time for users in any country
      final localDateTime = parsedDateTime.toLocal();

      return localDateTime;
    } catch (e) {
      debugPrint(
        'Error converting to local time: $e for input: $dateTimeString',
      );
      // Return current local time as fallback
      return DateTime.now(); // This is already in local timezone
    }
  }

  /// Format message time in 12-hour format based on device's local timezone
  static String formatMessageTime(String dateTimeString) {
    try {
      final dateTime = convertToLocalTime(dateTimeString);
      // Always return just time for chat bubble in 12-hour format
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '${displayHour.toString()}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      debugPrint('Error formatting message time: $e');
      return '';
    }
  }

  /// Format date separator for messages (WhatsApp style)
  /// Uses device's local timezone to show correct "Today"/"Yesterday"
  static String formatDateSeparator(String dateTimeString) {
    try {
      final messageDateTime = convertToLocalTime(dateTimeString);
      // Get current local time
      final nowLocal = DateTime.now();

      final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate = DateTime(
        messageDateTime.year,
        messageDateTime.month,
        messageDateTime.day,
      );

      if (messageDate == today) {
        return 'Today';
      } else if (messageDate == yesterday) {
        return 'Yesterday';
      } else {
        // Format as "DD MMM YYYY" for older messages
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final monthName = months[messageDateTime.month - 1];
        return '${messageDateTime.day} $monthName ${messageDateTime.year}';
      }
    } catch (e) {
      debugPrint('Error formatting date separator: $e');
      return 'Unknown Date';
    }
  }

  /// Get the date string for a message (for sticky header)
  /// Uses device's local timezone
  static String getMessageDateString(String dateTimeString) {
    try {
      final messageDateTime = convertToLocalTime(dateTimeString);
      return '${messageDateTime.year}-${messageDateTime.month.toString().padLeft(2, '0')}-${messageDateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('Error getting message date string: $e');
      return '';
    }
  }

  /// Format file size in human-readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Format duration for audio messages
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds % 60);
    return '$minutes:$seconds';
  }

  /// Parse dynamic value to int
  static int parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Check if date separator should be shown (WhatsApp style - once per date group)
  /// Uses device's local timezone for date comparison
  static bool shouldShowDateSeparator(List messages, int index) {
    try {
      // Since the ListView uses reverse: true, the index represents position from bottom
      // Index 0 = newest message (at bottom), higher indices = older messages (going up)

      // Get the current message (the one we're checking)
      final currentMessage = messages[messages.length - 1 - index];

      // If this is the oldest item in the list (top-most when reversed),
      // always show the date chip above it.
      final isOldestItem = (messages.length - 1 - index) == 0;
      if (isOldestItem) return true;

      // Compare with the previous item in display order (the one above = older)
      // If the date differs, current is the first message of its day group.
      final previousMessage = messages[messages.length - 1 - (index + 1)];

      final currentDateTime = convertToLocalTime(currentMessage.sentAt);
      final previousDateTime = convertToLocalTime(previousMessage.sentAt);

      final currentDate = DateTime(
        currentDateTime.year,
        currentDateTime.month,
        currentDateTime.day,
      );
      final previousDate = DateTime(
        previousDateTime.year,
        previousDateTime.month,
        previousDateTime.day,
      );

      // Place chip above the first message of the current date group
      final shouldShow = currentDate != previousDate;

      return shouldShow;
    } catch (e) {
      debugPrint('Error in shouldShowDateSeparator: $e');
      return false;
    }
  }

  /// Debug helper to print all message dates for troubleshooting
  /// Uses device's local timezone
  static void debugMessageDates(List messages) {
    for (int i = 0; i < messages.length; i++) {
      final message = messages[messages.length - 1 - i];
      final dateTime = convertToLocalTime(message.sentAt);
      final dateStr =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      final shouldShowSeparator = shouldShowDateSeparator(messages, i);
      debugPrint(
        '   Index $i: ${message.sentAt} -> $dateStr ${shouldShowSeparator ? '📅 SEPARATOR' : ''}',
      );
    }
  }

  /// Build typing indicator widget for both DM and group chats
  ///
  /// [typingDotAnimations] - List of animations for the typing dots
  /// [isGroupChat] - true for group chat, false for DM
  /// [userProfilePic] - Optional profile picture URL (for DM)
  /// [userName] - Optional user name for fallback avatar (for DM)
  static Widget buildTypingIndicator({
    required List<Animation<double>> typingDotAnimations,
    required bool isGroupChat,
    String? userProfilePic,
    String? userName,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[300],
            backgroundImage: !isGroupChat && userProfilePic != null
                ? CachedNetworkImageProvider(userProfilePic)
                : null,
            child: isGroupChat
                ? Icon(Icons.group, color: Colors.teal, size: 12)
                : (userProfilePic == null
                      ? Text(
                          userName != null && userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        )
                      : null),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(isGroupChat ? 16 : 14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [buildTypingAnimation(typingDotAnimations)],
            ),
          ),
        ],
      ),
    );
  }

  /// Cache media file for a message
  ///
  /// [url] - The media URL to cache
  /// [messageId] - The message ID
  /// [messagesRepo] - MessagesRepository instance
  /// [mediaCacheService] - MediaCacheService instance
  /// [checkExistingCache] - Whether to check if already cached (default: true)
  /// [debugPrefix] - Optional prefix for debug messages (e.g., "group message")
  static Future<void> cacheMediaForMessage({
    required String url,
    required int messageId,
    required dynamic mediaCacheService,
    bool checkExistingCache = true,
    String? debugPrefix,
  }) async {
    try {
      // Check if already cached in DB (only for DM, groups skip this check)
      if (checkExistingCache) {
        final hasLocalMedia = await messageRepo.hasLocalMedia(messageId);
        if (hasLocalMedia) {
          return;
        }
      }

      // Download and cache
      final localPath = await mediaCacheService.downloadAndCacheMedia(url);
      if (localPath != null) {
        // Update database with local path
        await messageRepo.updateLocalMediaPath(messageId, localPath);
        final prefix = debugPrefix != null ? '$debugPrefix ' : '';
      }
    } catch (e) {
      final prefix = debugPrefix != null ? '$debugPrefix ' : '';
      debugPrint('❌ Error caching media for $prefix$messageId: $e');
    }
  }

  /// Get media file path (local or remote)
  ///
  /// [url] - The media URL
  /// [localPath] - Optional local file path
  /// [mediaCacheService] - MediaCacheService instance
  static Future<String> getMediaPath({
    required String url,
    String? localPath,
    required dynamic mediaCacheService,
  }) async {
    // Check if local file exists
    if (localPath != null && io.File(localPath).existsSync()) {
      return localPath;
    }

    // Try to get from cache service
    final cachedPath = await mediaCacheService.getCachedFilePath(url);
    if (cachedPath != null) {
      return cachedPath;
    }

    // Return remote URL as fallback
    return url;
  }

  /// Toggle pin message
  ///
  /// [message] - The message to pin/unpin
  /// [conversationId] - The conversation ID
  /// [currentPinnedMessageId] - Current pinned message ID
  /// [setPinnedMessageId] - Setter for pinned message ID
  /// [currentUserId] - Current user ID
  /// [setState] - Callback to update state
  static Future<void> togglePinMessage({
    required MessageModel message,
    required int conversationId,
    required int? currentPinnedMessageId,
    required void Function(MessageModel?) setPinnedMessageId,
    required int? currentUserId,
    required void Function(void Function()) setState,
  }) async {
    final wasPinned = message.canonicalId == currentPinnedMessageId;

    setState(() {
      if (wasPinned) {
        setPinnedMessageId(null);
      } else {
        setPinnedMessageId(message);
      }
    });

    // Set to null when unpinning, otherwise set to message canonicalId
    final newPinnedMessageId = wasPinned ? null : message.canonicalId;

    await conversationRepo.updatePinnedMessage(
      conversationId,
      newPinnedMessageId,
    );

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final pinMessagePayload = MessagePinPayload(
      messageId: message.canonicalId!,
      messageType: message.type,
      senderId: currentUserId!,
      convId: conversationId,
      pin: !wasPinned,
    ).toJson();

    final wsmsg = WSMessage(
      type: WSMessageType.messagePin,
      payload: pinMessagePayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    webSocketService.sendMessage(wsmsg).catchError((e) {
      debugPrint('❌ Error sending message pin: $e');
    });
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  }

  /// Toggle star message
  ///
  /// [messageId] - The message ID to star/unstar
  /// [conversationId] - The conversation ID
  /// [starredMessages] - Set of starred message IDs
  /// [currentUserId] - Current user ID
  /// [setState] - Callback to update state
  static Future<void> toggleStarMessage({
    required int messageId,
    required int conversationId,
    required Set<int> starredMessages,
    required int? currentUserId,
    required void Function(void Function()) setState,
  }) async {
    final isCurrentlyStarred = starredMessages.contains(messageId);

    // Update UI immediately
    setState(() {
      if (isCurrentlyStarred) {
        starredMessages.remove(messageId);
      } else {
        starredMessages.add(messageId);
      }
    });

    // Save to local storage
    try {
      await messageRepo.toggleStarMessage(messageId);
    } catch (e) {
      debugPrint('❌ Error saving star state to storage: $e');
      // Revert UI state on storage error
      setState(() {
        if (isCurrentlyStarred) {
          starredMessages.add(messageId);
        } else {
          starredMessages.remove(messageId);
        }
      });
    }
  }

  /// Bulk star/unstar messages
  ///
  /// [conversationId] - The conversation ID
  /// [selectedMessages] - Set of selected message IDs
  /// [starredMessages] - Set of starred message IDs
  /// [currentUserId] - Current user ID
  /// [setState] - Callback to update state
  /// [exitSelectionMode] - Callback to exit selection mode
  static Future<void> bulkStarMessages({
    required int conversationId,
    required Set<int> selectedMessages,
    required Set<int> starredMessages,
    required int? currentUserId,
    required void Function(void Function()) setState,
    required void Function() exitSelectionMode,
  }) async {
    final messagesToStar = selectedMessages.toList();
    final areAllStarred = messagesToStar.every(
      (id) => starredMessages.contains(id),
    );

    // Determine action - if all are starred, unstar them; otherwise star them
    final action = areAllStarred ? 'unstar' : 'star';

    // Update UI immediately
    setState(() {
      if (areAllStarred) {
        starredMessages.removeAll(messagesToStar);
      } else {
        starredMessages.addAll(messagesToStar);
      }
    });
    exitSelectionMode();

    // Save each message to local storage
    try {
      for (final messageId in messagesToStar) {
        if (areAllStarred) {
          await messageRepo.unstarMessage(messageId);
        } else {
          await messageRepo.starMessage(messageId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error bulk ${action}ring messages in storage: $e');
      // Revert UI state on storage error
      setState(() {
        if (areAllStarred) {
          starredMessages.addAll(messagesToStar);
        } else {
          starredMessages.removeAll(messagesToStar);
        }
      });
    }
  }

  /// Bulk forward messages
  ///
  /// [selectedMessages] - Set of selected message IDs
  /// [messagesToForward] - Set of message IDs to forward (will be updated)
  /// [setState] - Callback to update state
  /// [exitSelectionMode] - Callback to exit selection mode
  /// [showForwardModal] - Callback to show forward modal
  static Future<void> bulkForwardMessages({
    required Set<int> selectedMessages,
    required Set<int> messagesToForward,
    required void Function(void Function()) setState,
    required void Function() exitSelectionMode,
    required Future<void> Function() showForwardModal,
  }) async {
    setState(() {
      messagesToForward.clear();
      messagesToForward.addAll(selectedMessages);
    });

    exitSelectionMode();
    await showForwardModal();
  }

  /// Initiate a call with a user (DM only)
  ///
  /// [context] - BuildContext for accessing Provider and Navigator
  /// [websocketService] - WebSocketService instance
  /// [userId] - The user ID to call
  /// [userName] - The user's name
  /// [userProfilePic] - Optional user profile picture URL
  static Future<void> initiateCall({
    required BuildContext context,
    required dynamic websocketService,
    required int userId,
    required String userName,
    String? userProfilePic,
  }) async {
    try {
      // Use CallService singleton directly (Riverpod provider wraps it)
      final callService = CallService();

      // Check WebSocket connection status
      if (!websocketService.isConnected) {
        await websocketService.connect();
        // await Future.delayed(const Duration(seconds: 1)); // Wait for connection
      }

      // Check if already in a call
      if (callService.hasActiveCall) {
        Snack.warning("Already in a call");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Already in a call'),
        //     backgroundColor: Colors.orange,
        //   ),
        // );
        return;
      }

      // Initiate the call - this will throw if it fails
      await callService.initiateCall(userId, userName, userProfilePic);

      // Check if we have an active call after initiation
      if (callService.hasActiveCall && context.mounted) {
        // Navigate to call screen
        Navigator.of(context).pushNamed('/call');
      } else {
        // If no active call, something went wrong
        debugPrint('[ChatHelpers] No active call after initiation');
      }
    } catch (e) {
      if (context.mounted) {
        Snack.error('Failed to start call: $e');
      }
    }
  }

  /// Check if a message is an image or video (for grid grouping)
  static bool isImageOrVideoMessage(MessageModel message) {
    final type = message.type.value.toLowerCase();
    if (type == 'image' || type == 'video') {
      return true;
    }
    
    // Check attachments category
    if (message.attachments != null) {
      final attachmentData = message.attachments as Map<String, dynamic>;
      final category = attachmentData['category'] as String?;
      if (category != null) {
        final categoryLower = category.toLowerCase();
        return categoryLower == 'images' || categoryLower == 'videos';
      }
    }
    
    return false;
  }

  /// Find consecutive media message groups (4 or more images/videos)
  /// Returns a list of ranges [startIndex, endIndex] for each group
  static List<MediaGroup> findConsecutiveMediaGroups(List<MessageModel> messages) {
    final groups = <MediaGroup>[];
    int? groupStart;
    int consecutiveCount = 0;

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      
      if (isImageOrVideoMessage(message)) {
        if (groupStart == null) {
          groupStart = i;
        }
        consecutiveCount++;
      } else {
        // Non-media message breaks the sequence
        if (consecutiveCount >= 4 && groupStart != null) {
          groups.add(MediaGroup(
            startIndex: groupStart,
            endIndex: i - 1,
            messages: messages.sublist(groupStart, i),
          ));
        }
        groupStart = null;
        consecutiveCount = 0;
      }
    }

    // Check if the last messages form a group
    if (consecutiveCount >= 4 && groupStart != null) {
      groups.add(MediaGroup(
        startIndex: groupStart,
        endIndex: messages.length - 1,
        messages: messages.sublist(groupStart),
      ));
    }

    return groups;
  }
}

/// Represents a group of consecutive media messages
class MediaGroup {
  final int startIndex;
  final int endIndex;
  final List<MessageModel> messages;

  MediaGroup({
    required this.startIndex,
    required this.endIndex,
    required this.messages,
  });
}
