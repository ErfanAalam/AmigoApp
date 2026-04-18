import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class MissedWsMessagesRepository {
  final sqliteDatabase = SqliteDatabase.instance;
  static const _uuid = Uuid();

  Future<void> storeEvent(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    final db = sqliteDatabase.database;
    final companion = MissedWsMessagesCompanion.insert(
      id: _uuid.v4(),
      eventType: eventType,
      payload: jsonEncode(payload),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await db.into(db.missedWsMessages).insert(companion);
  }

  Future<List<MissedWsMessage>> getAllPending() async {
    final db = sqliteDatabase.database;
    return (db.select(db.missedWsMessages)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> clearAll() async {
    final db = sqliteDatabase.database;
    await db.delete(db.missedWsMessages).go();
  }

  Future<void> clearOlderThan(DateTime cutoff) async {
    final db = sqliteDatabase.database;
    await (db.delete(db.missedWsMessages)
          ..where((t) => t.createdAt.isSmallerThanValue(
              cutoff.toUtc().toIso8601String())))
        .go();
  }
}
