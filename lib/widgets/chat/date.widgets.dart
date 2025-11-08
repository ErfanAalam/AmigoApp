import 'package:flutter/material.dart';
import '../../utils/chat_helpers.dart';

/// Common date separator widget for chat messages
/// Displays a formatted date (Today, Yesterday, or formatted date) with decorative lines
class DateSeparator extends StatelessWidget {
  final String dateTimeString;

  const DateSeparator({super.key, required this.dateTimeString});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Expanded(child: Container(height: 1, color: Colors.grey[300])),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              ChatHelpers.formatDateSeparator(dateTimeString),
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Expanded(child: Container(height: 1, color: Colors.grey[300])),
        ],
      ),
    );
  }
}

class DateDivider extends StatelessWidget {
  const DateDivider({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(date, style: const TextStyle(color: Colors.grey)),
  );
}
