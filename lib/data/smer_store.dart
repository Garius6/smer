import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/smer_entry.dart';

abstract class SmerStore {
  Future<List<SmerEntry>> loadEntries();
  Future<void> saveEntry(SmerEntry entry);
  Future<void> deleteEntry(String id);
  Future<bool> isOnboardingSeen();
  Future<void> markOnboardingSeen();
}

class SqliteSmerStore implements SmerStore {
  Database? _database;
  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      join(await getDatabasesPath(), 'smer.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE entries(id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, occurred_at INTEGER NOT NULL, situation TEXT NOT NULL, thoughts TEXT NOT NULL, emotions TEXT NOT NULL, body_reaction TEXT NOT NULL, behavior_reaction TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
    return _database!;
  }

  @override
  Future<List<SmerEntry>> loadEntries() async => (await (await _db).query(
    'entries',
    orderBy: 'occurred_at DESC',
  )).map(SmerEntry.fromRow).toList();
  @override
  Future<void> saveEntry(SmerEntry entry) async => (await _db).insert(
    'entries',
    entry.toRow(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  @override
  Future<void> deleteEntry(String id) async =>
      (await _db).delete('entries', where: 'id = ?', whereArgs: [id]);
  @override
  Future<bool> isOnboardingSeen() async => (await (await _db).query(
    'settings',
    where: 'key = ?',
    whereArgs: ['onboarding_seen'],
  )).isNotEmpty;
  @override
  Future<void> markOnboardingSeen() async => (await _db).insert('settings', {
    'key': 'onboarding_seen',
    'value': 'true',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
