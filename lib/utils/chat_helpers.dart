import 'package:flutter/material.dart';

class ChatHelpers {
  /// Convert UTC datetime string to IST
  static DateTime convertToIST(String dateTimeString) {
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

      // Convert to IST (UTC+5:30)
      final istDateTime = parsedDateTime.add(
        const Duration(hours: 5, minutes: 30),
      );

      return istDateTime;
    } catch (e) {
      debugPrint('Error converting to IST: $e for input: $dateTimeString');
      // Return current IST time as fallback
      return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    }
  }

  /// Format message time in 12-hour format
  static String formatMessageTime(String dateTimeString) {
    try {
      final dateTime = convertToIST(dateTimeString);
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

  /// Format date separator for messages
  static String formatDateSeparator(String dateTimeString) {
    try {
      final messageDateTime = convertToIST(dateTimeString);
      // Get current IST time
      final nowUTC = DateTime.now().toUtc();
      final nowIST = nowUTC.add(const Duration(hours: 5, minutes: 30));

      final today = DateTime(nowIST.year, nowIST.month, nowIST.day);
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
        // Format as "DD MMM YYYY" or "DD MMM" for current year
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

        if (messageDateTime.year == nowIST.year) {
          return '${messageDateTime.day} $monthName';
        } else {
          return '${messageDateTime.day} $monthName ${messageDateTime.year}';
        }
      }
    } catch (e) {
      debugPrint('Error formatting date separator: $e');
      return 'Unknown Date';
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

  /// Check if date separator should be shown
  static bool shouldShowDateSeparator(List messages, int index) {
    try {
      // Get the current message (the one we're checking)
      final currentMessage = messages[messages.length - 1 - index];

      // For the first message (newest), check if we need a separator
      if (index == 0) {
        // Always show separator for the first (newest) message
        return true;
      }

      // Get the previous message in the list (chronologically newer, displayed above)
      final previousMessage = messages[messages.length - index];

      // Convert both to IST and get date parts
      final currentDateTime = convertToIST(currentMessage.createdAt);
      final previousDateTime = convertToIST(previousMessage.createdAt);

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

      // Show separator if the current message is from a different date than the previous message
      return currentDate != previousDate;
    } catch (e) {
      debugPrint('Error in shouldShowDateSeparator: $e');
      return false;
    }
  }
}
