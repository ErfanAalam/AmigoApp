import 'package:drift/drift.dart';
import '../../models/call.model.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class CallRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert Calls row to CallModel
  /// Joins with Users/Contacts tables to get contact info
  Future<CallModel> _callToModel(Call call, String currentUserId) async {
    final db = sqliteDatabase.database;

    // Determine if this is an incoming or outgoing call
    final isIncoming = call.calleeId == currentUserId;
    final otherUserId = isIncoming ? call.callerId : call.calleeId;

    // Get contact info from Users table
    String contactName = 'Unknown';
    String? contactProfilePic;
    String contactId = otherUserId;

    final user = await (db.select(
      db.users,
    )..where((t) => t.id.equals(otherUserId))).getSingleOrNull();
    if (user != null) {
      contactName = user.username ?? user.name;
      contactProfilePic = user.profilePic;
      contactId = user.id;
    }

    // Parse dates
    DateTime? startedAt;
    DateTime? answeredAt;
    DateTime? endedAt;
    DateTime createdAt;

    try {
      startedAt = DateTime.parse(call.startedAt);
    } catch (_) {
      startedAt = DateTime.now();
    }

    if (call.answeredAt != null && call.answeredAt!.isNotEmpty) {
      try {
        answeredAt = DateTime.parse(call.answeredAt!);
      } catch (_) {
        answeredAt = null;
      }
    }

    if (call.endedAt != null && call.endedAt!.isNotEmpty) {
      try {
        endedAt = DateTime.parse(call.endedAt!);
      } catch (_) {
        endedAt = null;
      }
    }

    // Parse createdAt, fallback to startedAt if not available
    if (call.createdAt != null && call.createdAt!.isNotEmpty) {
      try {
        createdAt = DateTime.parse(call.createdAt!);
      } catch (_) {
        createdAt = startedAt ?? DateTime.now();
      }
    } else {
      createdAt = startedAt ?? DateTime.now();
    }

    // Use duration_seconds from DB if available, otherwise calculate
    int durationSeconds = call.durationSeconds;
    if (durationSeconds == 0 && endedAt != null && startedAt != null) {
      durationSeconds = endedAt.difference(startedAt).inSeconds;
    }

    return CallModel(
      id: call.id,
      callerId: call.callerId,
      calleeId: call.calleeId,
      contactId: contactId,
      contactName: contactName,
      contactProfilePic: contactProfilePic,
      startedAt: startedAt,
      answeredAt: answeredAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      status: CallStatus.fromString(call.status),
      reason: call.reason,
      callType: isIncoming ? CallType.incoming : CallType.outgoing,
      createdAt: createdAt,
    );
  }

  /// Insert a single call
  Future<void> insertCall(CallModel call) async {
    final db = sqliteDatabase.database;

    // Check if call already exists to preserve existing values
    final existingCall = await (db.select(
      db.calls,
    )..where((t) => t.id.equals(call.id))).getSingleOrNull();

    // Preserve existing values if call exists and new values are not provided
    final companion = CallsCompanion.insert(
      id: call.id,
      callerId: call.callerId,
      calleeId: call.calleeId,
      startedAt: call.startedAt.toIso8601String(),
      answeredAt: Value(call.answeredAt?.toIso8601String() ?? existingCall?.answeredAt),
      endedAt: Value(call.endedAt?.toIso8601String() ?? existingCall?.endedAt),
      durationSeconds: Value(call.durationSeconds),
      status: call.status.value,
      reason: Value(call.reason ?? existingCall?.reason),
      createdAt: call.createdAt.toIso8601String(),
    );
    await db.into(db.calls).insertOnConflictUpdate(companion);
  }

  /// Insert multiple calls (bulk insert)
  Future<void> insertCalls(List<CallModel> calls) async {
    if (calls.isEmpty) return;

    final db = sqliteDatabase.database;
    await db.transaction(() async {
      for (final call in calls) {
        // Check if call already exists to preserve existing values
        final existingCall = await (db.select(
          db.calls,
        )..where((t) => t.id.equals(call.id))).getSingleOrNull();

        // Preserve existing values if call exists and new values are not provided
        final companion = CallsCompanion.insert(
          id: call.id,
          callerId: call.callerId,
          calleeId: call.calleeId,
          startedAt: call.startedAt.toIso8601String(),
          answeredAt: Value(
            call.answeredAt?.toIso8601String() ?? existingCall?.answeredAt,
          ),
          endedAt: Value(
            call.endedAt?.toIso8601String() ?? existingCall?.endedAt,
          ),
          durationSeconds: Value(call.durationSeconds),
          status: call.status.value,
          reason: Value(call.reason ?? existingCall?.reason),
          createdAt: call.createdAt.toIso8601String(),
        );
        await db.into(db.calls).insertOnConflictUpdate(companion);
      }
    });
  }

  /// Get all calls for a user
  Future<List<CallModel>> getAllCalls(String userId) async {
    final db = sqliteDatabase.database;
    final calls =
        await (db.select(db.calls)
              ..where(
                (t) => t.callerId.equals(userId) | t.calleeId.equals(userId),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final results = <CallModel>[];
    for (final call in calls) {
      results.add(await _callToModel(call, userId));
    }
    return results;
  }

  /// Get calls by ID
  Future<CallModel?> getCallById(String callId, String currentUserId) async {
    final db = sqliteDatabase.database;
    final call = await (db.select(
      db.calls,
    )..where((t) => t.id.equals(callId))).getSingleOrNull();

    if (call == null) return null;
    return await _callToModel(call, currentUserId);
  }

  /// Get calls by status
  Future<List<CallModel>> getCallsByStatus(
    CallStatus status,
    String userId,
  ) async {
    final db = sqliteDatabase.database;
    final calls =
        await (db.select(db.calls)
              ..where(
                (t) =>
                    (t.callerId.equals(userId) | t.calleeId.equals(userId)) &
                    t.status.equals(status.value),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final results = <CallModel>[];
    for (final call in calls) {
      results.add(await _callToModel(call, userId));
    }
    return results;
  }

  /// Get calls by type (incoming/outgoing)
  Future<List<CallModel>> getCallsByType(CallType type, String userId) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.calls);

    // Filter by caller/callee based on call type
    if (type == CallType.incoming) {
      query.where((t) => t.calleeId.equals(userId));
    } else {
      query.where((t) => t.callerId.equals(userId));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
    ]);

    final calls = await query.get();

    final results = <CallModel>[];
    for (final call in calls) {
      results.add(await _callToModel(call, userId));
    }
    return results;
  }

  /// Get calls with a specific user
  Future<List<CallModel>> getCallsWithUser(String userId, String otherUserId) async {
    final db = sqliteDatabase.database;
    final calls =
        await (db.select(db.calls)
              ..where(
                (t) =>
                    (t.callerId.equals(userId) &
                        t.calleeId.equals(otherUserId)) |
                    (t.callerId.equals(otherUserId) &
                        t.calleeId.equals(userId)),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final results = <CallModel>[];
    for (final call in calls) {
      results.add(await _callToModel(call, userId));
    }
    return results;
  }

  /// Get missed calls
  Future<List<CallModel>> getMissedCalls(String userId) async {
    return getCallsByStatus(CallStatus.missed, userId);
  }

  /// Get declined calls
  Future<List<CallModel>> getDeclinedCalls(String userId) async {
    return getCallsByStatus(CallStatus.declined, userId);
  }

  /// Get recent calls (last N calls)
  Future<List<CallModel>> getRecentCalls(String userId, {int limit = 20}) async {
    final db = sqliteDatabase.database;
    final calls =
        await (db.select(db.calls)
              ..where(
                (t) => t.callerId.equals(userId) | t.calleeId.equals(userId),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();

    final results = <CallModel>[];
    for (final call in calls) {
      results.add(await _callToModel(call, userId));
    }
    return results;
  }

  /// Get calls in date range
  Future<List<CallModel>> getCallsInDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = sqliteDatabase.database;
    final startStr = startDate.toIso8601String();
    final endStr = endDate.toIso8601String();

    final calls =
        await (db.select(db.calls)
              ..where(
                (t) =>
                    (t.callerId.equals(userId) | t.calleeId.equals(userId)) &
                    t.startedAt.isBiggerOrEqualValue(startStr) &
                    t.startedAt.isSmallerOrEqualValue(endStr),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final results = <CallModel>[];
    for (final call in calls) {
      results.add(await _callToModel(call, userId));
    }
    return results;
  }

  /// Get calls for today
  Future<List<CallModel>> getTodayCalls(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getCallsInDateRange(userId, startOfDay, endOfDay);
  }

  /// Get calls for this week
  Future<List<CallModel>> getThisWeekCalls(String userId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final endOfDay = DateTime.now().add(const Duration(days: 1));

    return getCallsInDateRange(userId, startOfDay, endOfDay);
  }

  /// Get calls for this month
  Future<List<CallModel>> getThisMonthCalls(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime.now().add(const Duration(days: 1));

    return getCallsInDateRange(userId, startOfMonth, endOfMonth);
  }

  /// Update call status
  Future<void> updateCallStatus(String callId, CallStatus status) async {
    final db = sqliteDatabase.database;
    await (db.update(db.calls)..where((t) => t.id.equals(callId))).write(
      CallsCompanion(status: Value(status.value)),
    );
  }

  /// Update call end time and status
  Future<void> endCall(String callId, CallStatus status, DateTime? endedAt) async {
    final db = sqliteDatabase.database;
    final call = await (db.select(
      db.calls,
    )..where((t) => t.id.equals(callId))).getSingleOrNull();

    // Calculate duration if we have start and end times
    int? durationSeconds;
    if (endedAt != null && call != null) {
      try {
        final startTime = DateTime.parse(call.startedAt);
        durationSeconds = endedAt.difference(startTime).inSeconds;
      } catch (_) {
        // Keep existing duration if calculation fails
      }
    }

    await (db.update(db.calls)..where((t) => t.id.equals(callId))).write(
      CallsCompanion(
        status: Value(status.value),
        endedAt: Value(endedAt?.toIso8601String()),
        durationSeconds: durationSeconds != null ? Value(durationSeconds) : const Value.absent(),
      ),
    );
  }

  /// Get call count
  Future<int> getCallCount(String userId) async {
    final db = sqliteDatabase.database;
    final query = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(
        db.calls.callerId.equals(userId) | db.calls.calleeId.equals(userId),
      );

    final result = await query.getSingle();
    return result.read(db.calls.id.count()) ?? 0;
  }

  /// Get call count by status
  Future<int> getCallCountByStatus(String userId, CallStatus status) async {
    final db = sqliteDatabase.database;
    final query = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(
        (db.calls.callerId.equals(userId) | db.calls.calleeId.equals(userId)) &
            db.calls.status.equals(status.value),
      );

    final result = await query.getSingle();
    return result.read(db.calls.id.count()) ?? 0;
  }

  /// Get call count by type
  Future<int> getCallCountByType(String userId, CallType type) async {
    final db = sqliteDatabase.database;

    final query = db.selectOnly(db.calls)..addColumns([db.calls.id.count()]);

    // Filter by caller/callee based on call type
    if (type == CallType.incoming) {
      query.where(db.calls.calleeId.equals(userId));
    } else {
      query.where(db.calls.callerId.equals(userId));
    }

    final result = await query.getSingle();
    return result.read(db.calls.id.count()) ?? 0;
  }

  /// Get missed call count
  Future<int> getMissedCallCount(String userId) async {
    return getCallCountByStatus(userId, CallStatus.missed);
  }

  /// Delete a call
  Future<bool> deleteCall(String callId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.calls,
    )..where((t) => t.id.equals(callId))).go();
    return deleted > 0;
  }

  /// Delete multiple calls
  Future<int> deleteCalls(List<String> callIds) async {
    if (callIds.isEmpty) return 0;

    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.calls,
    )..where((t) => t.id.isIn(callIds))).go();
    return deleted;
  }

  /// Delete all calls for a user
  Future<void> deleteAllCalls(String userId) async {
    final db = sqliteDatabase.database;
    await (db.delete(db.calls)
          ..where((t) => t.callerId.equals(userId) | t.calleeId.equals(userId)))
        .go();
  }

  /// Delete calls by status
  Future<int> deleteCallsByStatus(String userId, CallStatus status) async {
    final db = sqliteDatabase.database;
    final deleted =
        await (db.delete(db.calls)..where(
              (t) =>
                  (t.callerId.equals(userId) | t.calleeId.equals(userId)) &
                  t.status.equals(status.value),
            ))
            .go();
    return deleted;
  }

  /// Delete old calls (older than specified days)
  Future<int> deleteOldCalls(String userId, int daysOld) async {
    final db = sqliteDatabase.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    final cutoffStr = cutoffDate.toIso8601String();

    final deleted =
        await (db.delete(db.calls)..where(
              (t) =>
                  (t.callerId.equals(userId) | t.calleeId.equals(userId)) &
                  t.startedAt.isSmallerThanValue(cutoffStr),
            ))
            .go();
    return deleted;
  }

  /// Check if call exists
  Future<bool> callExists(String callId) async {
    final db = sqliteDatabase.database;
    final call = await (db.select(
      db.calls,
    )..where((t) => t.id.equals(callId))).getSingleOrNull();
    return call != null;
  }

  /// Get last call with a user
  Future<CallModel?> getLastCallWithUser(String userId, String otherUserId) async {
    final db = sqliteDatabase.database;
    final call =
        await (db.select(db.calls)
              ..where(
                (t) =>
                    (t.callerId.equals(userId) &
                        t.calleeId.equals(otherUserId)) |
                    (t.callerId.equals(otherUserId) &
                        t.calleeId.equals(userId)),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (call == null) return null;
    return await _callToModel(call, userId);
  }

  /// Get call statistics for a user
  Future<Map<String, dynamic>> getCallStatistics(String userId) async {
    final db = sqliteDatabase.database;

    // Total calls
    final totalQuery = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(
        db.calls.callerId.equals(userId) | db.calls.calleeId.equals(userId),
      );
    final totalResult = await totalQuery.getSingle();
    final total = totalResult.read(db.calls.id.count()) ?? 0;

    // Incoming calls
    final incomingQuery = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(db.calls.calleeId.equals(userId));
    final incomingResult = await incomingQuery.getSingle();
    final incoming = incomingResult.read(db.calls.id.count()) ?? 0;

    // Outgoing calls
    final outgoingQuery = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(db.calls.callerId.equals(userId));
    final outgoingResult = await outgoingQuery.getSingle();
    final outgoing = outgoingResult.read(db.calls.id.count()) ?? 0;

    // Missed calls
    final missedQuery = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(
        (db.calls.callerId.equals(userId) | db.calls.calleeId.equals(userId)) &
            db.calls.status.equals(CallStatus.missed.value),
      );
    final missedResult = await missedQuery.getSingle();
    final missed = missedResult.read(db.calls.id.count()) ?? 0;

    // Declined calls
    final declinedQuery = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(
        (db.calls.callerId.equals(userId) | db.calls.calleeId.equals(userId)) &
            db.calls.status.equals(CallStatus.declined.value),
      );
    final declinedResult = await declinedQuery.getSingle();
    final declined = declinedResult.read(db.calls.id.count()) ?? 0;

    // Answered calls
    final answeredQuery = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(
        (db.calls.callerId.equals(userId) | db.calls.calleeId.equals(userId)) &
            db.calls.status.equals(CallStatus.answered.value),
      );
    final answeredResult = await answeredQuery.getSingle();
    final answered = answeredResult.read(db.calls.id.count()) ?? 0;

    return {
      'total': total,
      'incoming': incoming,
      'outgoing': outgoing,
      'missed': missed,
      'declined': declined,
      'answered': answered,
    };
  }

  /// Get total call duration for a user (in seconds)
  Future<int> getTotalCallDuration(String userId) async {
    final calls = await getAllCalls(userId);
    int totalDuration = 0;

    for (final call in calls) {
      if (call.endedAt != null) {
        totalDuration += call.durationSeconds;
      }
    }

    return totalDuration;
  }

  /// Get total call duration with a specific user (in seconds)
  Future<int> getTotalCallDurationWithUser(String userId, String otherUserId) async {
    final calls = await getCallsWithUser(userId, otherUserId);
    int totalDuration = 0;

    for (final call in calls) {
      if (call.endedAt != null) {
        totalDuration += call.durationSeconds;
      }
    }

    return totalDuration;
  }

  /// Get active/ongoing calls (calls without endedAt)
  Future<List<CallModel>> getActiveCalls(String userId) async {
    final db = sqliteDatabase.database;
    final calls =
        await (db.select(db.calls)
              ..where(
                (t) =>
                    (t.callerId.equals(userId) | t.calleeId.equals(userId)) &
                    t.endedAt.isNull(),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final results = <CallModel>[];
    for (final call in calls) {
      results.add(await _callToModel(call, userId));
    }
    return results;
  }

  /// Clear all calls
  Future<void> clearAllCalls() async {
    final db = sqliteDatabase.database;
    await db.delete(db.calls).go();
  }

  /// Search calls by contact name
  Future<List<CallModel>> searchCalls(String userId, String searchQuery) async {
    final allCalls = await getAllCalls(userId);

    // Filter calls where contact name contains search query
    return allCalls
        .where(
          (call) => call.contactName.toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  /// Get calls grouped by contact
  Future<Map<String, List<CallModel>>> getCallsGroupedByContact(String userId) async {
    final calls = await getAllCalls(userId);
    final grouped = <String, List<CallModel>>{};

    for (final call in calls) {
      final contactId = call.contactId;
      if (!grouped.containsKey(contactId)) {
        grouped[contactId] = [];
      }
      grouped[contactId]!.add(call);
    }

    return grouped;
  }

  /// Get most called contacts (top N)
  Future<List<Map<String, dynamic>>> getMostCalledContacts(
    String userId, {
    int limit = 10,
  }) async {
    final grouped = await getCallsGroupedByContact(userId);
    final contactStats = <Map<String, dynamic>>[];

    for (final entry in grouped.entries) {
      final calls = entry.value;
      final contactId = entry.key;
      final contactName = calls.first.contactName;
      final contactProfilePic = calls.first.contactProfilePic;

      contactStats.add({
        'contactId': contactId,
        'contactName': contactName,
        'contactProfilePic': contactProfilePic,
        'callCount': calls.length,
        'lastCall': calls.first.startedAt,
      });
    }

    // Sort by call count descending
    contactStats.sort(
      (a, b) => (b['callCount'] as int).compareTo(a['callCount'] as int),
    );

    return contactStats.take(limit).toList();
  }
}
