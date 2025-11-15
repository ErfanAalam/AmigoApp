// lib/repositories/call_repository.dart
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/call_model.dart';

class CallRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertOrUpdateCall(CallModel call) async {
    final db = await dbHelper.database;
    return await db.insert(
      'calls',
      call.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace, // replace if same id exists
    );
  }

  Future<List<CallModel>> getAllCalls({int limit = 50}) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'calls',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map((row) => CallModel.fromJson(row)).toList();
  }

  Future<void> insertOrUpdateCallList(List<CallModel> calls) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (var call in calls) {
      batch.insert(
        'calls',
        call.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteCall(int id) async {
    final db = await dbHelper.database;
    return await db.delete('calls', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCalls() async {
    final db = await dbHelper.database;
    await db.delete('calls');
  }
}
