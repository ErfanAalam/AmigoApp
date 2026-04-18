class Snowflake {
  static const int _epoch = 1577836800000; // 2020-01-01
  static const int _nodeId = 1 & 0x1F; // 5 bits: 0–31
  static int _sequence = 0;
  static int _lastTimestamp = -1;

  /// Monotonic positive int suitable for local correlation / event IDs.
  /// Not used as a message PK anymore (UUIDv7 handles that via id.utils.dart).
  static int generatePositive() {
    int timestamp = DateTime.now().millisecondsSinceEpoch;

    if (timestamp == _lastTimestamp) {
      _sequence = (_sequence + 1) & 0x7F;
      if (_sequence == 0) {
        while (timestamp <= _lastTimestamp) {
          timestamp = DateTime.now().millisecondsSinceEpoch;
        }
      }
    } else {
      _sequence = 0;
    }

    _lastTimestamp = timestamp;
    return ((timestamp - _epoch) << 12) | (_nodeId << 7) | _sequence;
  }
}
