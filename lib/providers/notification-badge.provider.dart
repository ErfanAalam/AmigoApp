import 'dart:async';
import 'package:amigo/db/repositories/call.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/services/call/call-seen.store.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notification badge counts state
class NotificationBadgeState {
  final int chatCount;
  final int groupCount;
  final int callCount;

  const NotificationBadgeState({
    this.chatCount = 0,
    this.groupCount = 0,
    this.callCount = 0,
  });

  NotificationBadgeState copyWith({
    int? chatCount,
    int? groupCount,
    int? callCount,
  }) {
    return NotificationBadgeState(
      chatCount: chatCount ?? this.chatCount,
      groupCount: groupCount ?? this.groupCount,
      callCount: callCount ?? this.callCount,
    );
  }
}

/// Provider for notification badge counts
final notificationBadgeProvider =
    NotifierProvider<NotificationBadgeNotifier, NotificationBadgeState>(() {
      return NotificationBadgeNotifier();
    });

class NotificationBadgeNotifier extends Notifier<NotificationBadgeState> {
  final ConversationRepository _conversationsRepo = ConversationRepository();
  final CallRepository _callRepo = CallRepository();
  final CallSeenStore _callSeenStore = CallSeenStore();

  Timer? _refreshTimer;
  StreamSubscription? _subscription;

  @override
  NotificationBadgeState build() {
    // Load counts asynchronously
    Future.microtask(() => _refreshCounts());

    // Set up periodic refresh (every 5 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshCounts();
    });

    // Cleanup on dispose
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _subscription?.cancel();
    });

    return const NotificationBadgeState();
  }

  /// Refresh all badge counts
  Future<void> _refreshCounts() async {
    try {
      final chatCount = await _getUnreadChatCount();
      final groupCount = await _getUnreadGroupCount();
      final callCount = await _getUnseenMissedCallCount();

      state = NotificationBadgeState(
        chatCount: chatCount,
        groupCount: groupCount,
        callCount: callCount,
      );
    } catch (e) {
      // Silently handle errors
      debugPrint('Error refreshing badge counts: $e');
    }
  }

  /// Get total unread chat count
  Future<int> _getUnreadChatCount() async {
    try {
      final conversations = await _conversationsRepo.getConversationsByType(
        ChatType.dm,
      );
      int total = 0;
      for (final conv in conversations) {
        if (conv.unreadCount != null && conv.unreadCount! > 0) {
          total += conv.unreadCount!;
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of groups with unread messages
  Future<int> _getUnreadGroupCount() async {
    try {
      final groups = await _conversationsRepo.getConversationsByType(
        ChatType.group,
      );
      int count = 0;
      for (final group in groups) {
        if (group.unreadCount != null && group.unreadCount! > 0) {
          count++; // Count groups with unread messages, not total messages
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of unseen missed calls — incoming missed calls in the local DB
  /// (the single source of truth, incl. background/killed-app misses) whose IDs
  /// aren't yet in the SharedPreferences-backed seen set.
  Future<int> _getUnseenMissedCallCount() async {
    try {
      final currentUser = await UserUtils().getUserDetails();
      final userId = currentUser?.id ?? '';
      if (userId.isEmpty) return 0;

      final missedIds = await _callRepo.getIncomingMissedCallIds(userId);
      if (missedIds.isEmpty) return 0;

      final seenCallIds = await _callSeenStore.getSeenCallIds();
      return missedIds.where((id) => !seenCallIds.contains(id)).length;
    } catch (e) {
      return 0;
    }
  }

  /// Manually refresh counts (call this when needed)
  Future<void> refresh() async {
    await _refreshCounts();
  }

  /// Mark all current missed calls as seen — call this when the user views the
  /// Calls tab. Persists the full set of current incoming-missed IDs (which both
  /// acknowledges them and prunes stale entries), then refreshes the badge to 0.
  Future<void> markCallsAsSeen() async {
    try {
      final currentUser = await UserUtils().getUserDetails();
      final userId = currentUser?.id ?? '';
      if (userId.isEmpty) return;

      final missedIds = await _callRepo.getIncomingMissedCallIds(userId);
      await _callSeenStore.setSeenCallIds(missedIds.toSet());
      await _refreshCounts();
    } catch (e) {
      debugPrint('Error marking calls as seen: $e');
    }
  }

  /// Clear all badge counts (used during logout). Also drops the persisted
  /// seen-set so the next user doesn't inherit this user's acknowledgements.
  void clearAllCounts() {
    state = const NotificationBadgeState();
    unawaited(_callSeenStore.clear());
  }
}
