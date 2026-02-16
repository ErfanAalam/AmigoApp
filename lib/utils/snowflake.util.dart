import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'user.utils.dart';

class Snowflake {
  static const int _epoch = 1577836800000; // 2020-01-01
  static const int _nodeId = 1 & 0x1F; // 5 bits: 0–31
  static int _sequence = 0;
  static int _lastTimestamp = -1;

  static int generatePositive() {
    int timestamp = DateTime.now().millisecondsSinceEpoch;

    if (timestamp == _lastTimestamp) {
      _sequence = (_sequence + 1) & 0x7F; // 7 bits: 0–127
      if (_sequence == 0) {
        while (timestamp <= _lastTimestamp) {
          timestamp = DateTime.now().millisecondsSinceEpoch;
        }
      }
    } else {
      _sequence = 0;
    }

    _lastTimestamp = timestamp;

    final id = ((timestamp - _epoch) << 12) | (_nodeId << 7) | _sequence;

    return id;
  }

  // static int generateNegative() {
  //   int timestamp = DateTime.now().millisecondsSinceEpoch;
  //
  //   if (timestamp == _lastTimestamp) {
  //     _sequence = (_sequence + 1) & 0x7F; // 7 bits: 0–127
  //     if (_sequence == 0) {
  //       while (timestamp <= _lastTimestamp) {
  //         timestamp = DateTime.now().millisecondsSinceEpoch;
  //       }
  //     }
  //   } else {
  //     _sequence = 0;
  //   }
  //
  //   _lastTimestamp = timestamp;
  //
  //   final id = ((timestamp - _epoch) << 12) | (_nodeId << 7) | _sequence;
  //
  //   return -id;
  // }

  static Future<int> generateMessageId([int? conversationId]) async {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    // Get userId from UserUtils, or use random 15-digit number if not available
    final userDetails = await UserUtils().getUserDetails();
    final int userId = userDetails?.id ?? _generateRandom15Digit();

    // Use provided conversationId if available, otherwise random 15-digit number
    final int convId = conversationId ?? _generateRandom15Digit();

    // Extra randomness to protect against same-ms retries
    final random = Random.secure().nextInt(1 << 20); // ~1M space

    final input = utf8.encode('$userId:$convId:$timestampMs:$random');

    final hash = sha256.convert(input).bytes;

    // Take first 8 bytes = 64 bits
    int id = 0;
    for (int i = 0; i < 8; i++) {
      id = (id << 8) | hash[i];
    }

    // Force into signed BIGINT positive range (63 bits)
    id &= 0x7FFFFFFFFFFFFFFF;

    // // Force into JS safe integer range (53 bits)
    // id &= 0x1FFFFFFFFFFFFF;

    return id;
  }

  /// Generate a random 15-digit positive integer (no leading zeros).
  static int _generateRandom15Digit() {
    final rand = Random.secure();
    final buffer = StringBuffer();

    // First digit: 1–9 to avoid leading zero
    buffer.write(rand.nextInt(9) + 1);

    // Remaining 14 digits: 0–9
    for (int i = 1; i < 15; i++) {
      buffer.write(rand.nextInt(10));
    }

    return int.parse(buffer.toString());
  }
}
