// lib/db/database_helper.dart
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _db;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('amigo_chat_app.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // initial create
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        profile_pic TEXT,
        call_access INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 0, -- 0/1 flag for pending local updates
        updated_at INTEGER -- unix ms, optional
      );
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        profile_pic TEXT,
        updated_at INTEGER
      );
    ''');

    await db.execute('''
    CREATE TABLE calls (
      id INTEGER PRIMARY KEY,
      caller_id INTEGER NOT NULL,
      callee_id INTEGER NOT NULL,
      contact_id INTEGER NOT NULL,
      contact_name TEXT,
      contact_profile_pic TEXT,
      started_at TEXT NOT NULL,
      answered_at TEXT,
      ended_at TEXT,
      duration_seconds INTEGER NOT NULL,
      status TEXT NOT NULL,
      reason TEXT,
      call_type TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');
  }

  // simple migration example
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // add contacts table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        profile_pic TEXT,
        updated_at INTEGER
      );
    ''');

      // create calls table for existing DB
      await db.execute('''
      CREATE TABLE IF NOT EXISTS calls (
        id INTEGER PRIMARY KEY,
        caller_id INTEGER NOT NULL,
        callee_id INTEGER NOT NULL,
        contact_id INTEGER NOT NULL,
        contact_name TEXT,
        contact_profile_pic TEXT,
        started_at TEXT NOT NULL,
        answered_at TEXT,
        ended_at TEXT,
        duration_seconds INTEGER NOT NULL,
        status TEXT NOT NULL,
        reason TEXT,
        call_type TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    }
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
    _db = null;
  }
}
