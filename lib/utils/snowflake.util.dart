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

  static int generateNegative() {
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

    return -id;
  }
}
