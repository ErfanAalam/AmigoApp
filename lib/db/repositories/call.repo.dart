import 'package:amigo/models/call_model.dart';
import 'package:drift/drift.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class CallRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert Calls row to CallModel
  /// Joins with Users/Contacts tables to get contact info
  Future<CallModel> _callToModel(Call call, int currentUserId) async {
    final db = sqliteDatabase.database;

    // Determine if this is an incoming or outgoing call
    final isIncoming = call.calleeId == currentUserId;
    final otherUserId = isIncoming ? call.callerId : call.calleeId;

    // Try to get contact info from Contacts table first
    Contact? contact = await (db.select(
      db.contacts,
    )..where((t) => t.id.equals(otherUserId))).getSingleOrNull();

    // If not found in contacts, try Users table
    String contactName = 'Unknown';
    String? contactProfilePic;
    int contactId = otherUserId;

    if (contact != null) {
      contactName = contact.name;
      contactProfilePic = contact.profilePic;
      contactId = contact.id;
    } else {
      final user = await (db.select(
        db.users,
      )..where((t) => t.id.equals(otherUserId))).getSingleOrNull();
      if (user != null) {
        contactName = user.name;
        contactProfilePic = user.profilePic;
        contactId = user.id;
      }
    }

    // Calculate duration if call has ended
    int durationSeconds = 0;
    if (call.endedAt != null && call.endedAt!.isNotEmpty) {
      try {
        final startTime = DateTime.parse(call.startedAt);
        final endTime = DateTime.parse(call.endedAt!);
        durationSeconds = endTime.difference(startTime).inSeconds;
      } catch (_) {
        durationSeconds = 0;
      }
    }

    // Parse dates
    DateTime? startedAt;
    DateTime? endedAt;
    DateTime createdAt;

    try {
      startedAt = DateTime.parse(call.startedAt);
      createdAt = startedAt;
    } catch (_) {
      startedAt = DateTime.now();
      createdAt = DateTime.now();
    }

    if (call.endedAt != null && call.endedAt!.isNotEmpty) {
      try {
        endedAt = DateTime.parse(call.endedAt!);
      } catch (_) {
        endedAt = null;
      }
    }

    return CallModel(
      id: call.id,
      callerId: call.callerId,
      calleeId: call.calleeId,
      contactId: contactId,
      contactName: contactName,
      contactProfilePic: contactProfilePic,
      startedAt: startedAt,
      answeredAt: null, // Not stored in DB, would need to be added
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      status: CallStatus.fromString(call.status),
      reason: null, // Not stored in DB
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
      id: Value(call.id),
      callerId: call.callerId,
      calleeId: call.calleeId,
      startedAt: call.startedAt.toIso8601String(),
      endedAt: Value(call.endedAt?.toIso8601String() ?? existingCall?.endedAt),
      status: call.status.value,
      callType: call.callType == CallType.incoming ? 'incoming' : 'outgoing',
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
          id: Value(call.id),
          callerId: call.callerId,
          calleeId: call.calleeId,
          startedAt: call.startedAt.toIso8601String(),
          endedAt: Value(
            call.endedAt?.toIso8601String() ?? existingCall?.endedAt,
          ),
          status: call.status.value,
          callType: call.callType == CallType.incoming
              ? 'incoming'
              : 'outgoing',
        );
        await db.into(db.calls).insertOnConflictUpdate(companion);
      }
    });
  }

  /// Get all calls for a user
  Future<List<CallModel>> getAllCalls(int userId) async {
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
  Future<CallModel?> getCallById(int callId, int currentUserId) async {
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
    int userId,
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
  Future<List<CallModel>> getCallsByType(CallType type, int userId) async {
    final db = sqliteDatabase.database;
    final callTypeStr = type == CallType.incoming ? 'incoming' : 'outgoing';

    final query = db.select(db.calls);

    if (type == CallType.incoming) {
      query.where((t) => t.calleeId.equals(userId));
    } else {
      query.where((t) => t.callerId.equals(userId));
    }

    query
      ..where((t) => t.callType.equals(callTypeStr))
      ..orderBy([
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
  Future<List<CallModel>> getCallsWithUser(int userId, int otherUserId) async {
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
  Future<List<CallModel>> getMissedCalls(int userId) async {
    return getCallsByStatus(CallStatus.missed, userId);
  }

  /// Get declined calls
  Future<List<CallModel>> getDeclinedCalls(int userId) async {
    return getCallsByStatus(CallStatus.declined, userId);
  }

  /// Get recent calls (last N calls)
  Future<List<CallModel>> getRecentCalls(int userId, {int limit = 20}) async {
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
    int userId,
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
  Future<List<CallModel>> getTodayCalls(int userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getCallsInDateRange(userId, startOfDay, endOfDay);
  }

  /// Get calls for this week
  Future<List<CallModel>> getThisWeekCalls(int userId) async {
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
  Future<List<CallModel>> getThisMonthCalls(int userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime.now().add(const Duration(days: 1));

    return getCallsInDateRange(userId, startOfMonth, endOfMonth);
  }

  /// Update call status
  Future<void> updateCallStatus(int callId, CallStatus status) async {
    final db = sqliteDatabase.database;
    await (db.update(db.calls)..where((t) => t.id.equals(callId))).write(
      CallsCompanion(status: Value(status.value)),
    );
  }

  /// Update call end time and status
  Future<void> endCall(int callId, CallStatus status, DateTime? endedAt) async {
    final db = sqliteDatabase.database;
    await (db.update(db.calls)..where((t) => t.id.equals(callId))).write(
      CallsCompanion(
        status: Value(status.value),
        endedAt: Value(endedAt?.toIso8601String()),
      ),
    );
  }

  /// Get call count
  Future<int> getCallCount(int userId) async {
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
  Future<int> getCallCountByStatus(int userId, CallStatus status) async {
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
  Future<int> getCallCountByType(int userId, CallType type) async {
    final db = sqliteDatabase.database;
    final callTypeStr = type == CallType.incoming ? 'incoming' : 'outgoing';

    final query = db.selectOnly(db.calls)..addColumns([db.calls.id.count()]);

    if (type == CallType.incoming) {
      query.where(
        db.calls.calleeId.equals(userId) &
            db.calls.callType.equals(callTypeStr),
      );
    } else {
      query.where(
        db.calls.callerId.equals(userId) &
            db.calls.callType.equals(callTypeStr),
      );
    }

    final result = await query.getSingle();
    return result.read(db.calls.id.count()) ?? 0;
  }

  /// Get missed call count
  Future<int> getMissedCallCount(int userId) async {
    return getCallCountByStatus(userId, CallStatus.missed);
  }

  /// Delete a call
  Future<bool> deleteCall(int callId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.calls,
    )..where((t) => t.id.equals(callId))).go();
    return deleted > 0;
  }

  /// Delete multiple calls
  Future<int> deleteCalls(List<int> callIds) async {
    if (callIds.isEmpty) return 0;

    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.calls,
    )..where((t) => t.id.isIn(callIds))).go();
    return deleted;
  }

  /// Delete all calls for a user
  Future<void> deleteAllCalls(int userId) async {
    final db = sqliteDatabase.database;
    await (db.delete(db.calls)
          ..where((t) => t.callerId.equals(userId) | t.calleeId.equals(userId)))
        .go();
  }

  /// Delete calls by status
  Future<int> deleteCallsByStatus(int userId, CallStatus status) async {
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
  Future<int> deleteOldCalls(int userId, int daysOld) async {
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
  Future<bool> callExists(int callId) async {
    final db = sqliteDatabase.database;
    final call = await (db.select(
      db.calls,
    )..where((t) => t.id.equals(callId))).getSingleOrNull();
    return call != null;
  }

  /// Get last call with a user
  Future<CallModel?> getLastCallWithUser(int userId, int otherUserId) async {
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
  Future<Map<String, dynamic>> getCallStatistics(int userId) async {
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
      ..where(
        db.calls.calleeId.equals(userId) & db.calls.callType.equals('incoming'),
      );
    final incomingResult = await incomingQuery.getSingle();
    final incoming = incomingResult.read(db.calls.id.count()) ?? 0;

    // Outgoing calls
    final outgoingQuery = db.selectOnly(db.calls)
      ..addColumns([db.calls.id.count()])
      ..where(
        db.calls.callerId.equals(userId) & db.calls.callType.equals('outgoing'),
      );
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
  Future<int> getTotalCallDuration(int userId) async {
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
  Future<int> getTotalCallDurationWithUser(int userId, int otherUserId) async {
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
  Future<List<CallModel>> getActiveCalls(int userId) async {
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
  Future<List<CallModel>> searchCalls(int userId, String searchQuery) async {
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
  Future<Map<int, List<CallModel>>> getCallsGroupedByContact(int userId) async {
    final calls = await getAllCalls(userId);
    final grouped = <int, List<CallModel>>{};

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
    int userId, {
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
