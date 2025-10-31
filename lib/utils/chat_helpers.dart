import 'package:flutter/material.dart';

class ChatHelpers {
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

      final currentDateTime = convertToLocalTime(currentMessage.createdAt);
      final previousDateTime = convertToLocalTime(previousMessage.createdAt);

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
      final dateTime = convertToLocalTime(message.createdAt);
      final dateStr =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      final shouldShowSeparator = shouldShowDateSeparator(messages, i);
      debugPrint(
        '   Index $i: ${message.createdAt} -> $dateStr ${shouldShowSeparator ? '📅 SEPARATOR' : ''}',
      );
    }
  }
}
