import 'package:shared_preferences/shared_preferences.dart';

/// Service to track which calls have been seen by the user
/// When the call screen is viewed, all missed calls are marked as seen
class CallSeenService {
  static const String _seenCallsKey = 'seen_call_ids';
  static CallSeenService? _instance;
  SharedPreferences? _prefs;

  CallSeenService._();

  static CallSeenService get instance {
    _instance ??= CallSeenService._();
    return _instance!;
  }

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Mark a call as seen
  Future<void> markCallAsSeen(int callId) async {
    await _ensureInitialized();
    final seenCalls = await getSeenCallIds();
    seenCalls.add(callId);
    await _prefs!.setStringList(
      _seenCallsKey,
      seenCalls.map((id) => id.toString()).toList(),
    );
  }

  /// Mark multiple calls as seen
  Future<void> markCallsAsSeen(List<int> callIds) async {
    await _ensureInitialized();
    final seenCalls = await getSeenCallIds();
    seenCalls.addAll(callIds);
    await _prefs!.setStringList(
      _seenCallsKey,
      seenCalls.map((id) => id.toString()).toList(),
    );
  }

  /// Get all seen call IDs
  Future<Set<int>> getSeenCallIds() async {
    await _ensureInitialized();
    final seenIdsList = _prefs!.getStringList(_seenCallsKey) ?? [];
    return seenIdsList
        .map((id) => int.tryParse(id) ?? 0)
        .where((id) => id > 0)
        .toSet();
  }

  /// Check if a call has been seen
  Future<bool> isCallSeen(int callId) async {
    final seenCalls = await getSeenCallIds();
    return seenCalls.contains(callId);
  }

  /// Clear all seen calls (useful for testing or reset)
  Future<void> clearSeenCalls() async {
    await _ensureInitialized();
    await _prefs!.remove(_seenCallsKey);
  }
}
