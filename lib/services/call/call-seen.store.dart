import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the IDs of missed calls the user has already seen, so the Calls-tab
/// badge can show only *unseen* missed calls and survive app restarts.
///
/// This store only owns the "seen" bookmark in SharedPreferences. The unseen
/// count itself is derived by [NotificationBadgeNotifier] as
/// (incoming missed calls in SQLite ∖ this set) — SQLite stays the single
/// source of truth (it already captures killed-app/background misses via
/// `StreamCallLogger.recordColdMissed`), and this set just tracks acknowledgement.
class CallSeenStore {
  static const String _seenMissedCallsKey = 'seen_missed_call_ids';

  // Singleton — mirrors DraftMessageService so there's a single prefs handle.
  static final CallSeenStore _instance = CallSeenStore._internal();
  factory CallSeenStore() => _instance;
  CallSeenStore._internal();

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// The IDs of missed calls the user has already acknowledged.
  Future<Set<String>> getSeenCallIds() async {
    await _initPrefs();
    try {
      final raw = _prefs!.getStringList(_seenMissedCallsKey);
      return raw?.toSet() ?? <String>{};
    } catch (e) {
      debugPrint('❌ Error reading seen call ids: $e');
      return <String>{};
    }
  }

  /// Replace the seen-set with [ids]. Callers pass the full set of currently
  /// missed call IDs, so this both marks them seen and prunes stale entries
  /// (keeping the stored set bounded to what's still in the call log).
  Future<void> setSeenCallIds(Set<String> ids) async {
    await _initPrefs();
    try {
      await _prefs!.setStringList(_seenMissedCallsKey, ids.toList());
    } catch (e) {
      debugPrint('❌ Error saving seen call ids: $e');
    }
  }

  /// Drop all seen state (e.g. on logout, so the next user starts clean).
  Future<void> clear() async {
    await _initPrefs();
    try {
      await _prefs!.remove(_seenMissedCallsKey);
    } catch (e) {
      debugPrint('❌ Error clearing seen call ids: $e');
    }
  }
}
