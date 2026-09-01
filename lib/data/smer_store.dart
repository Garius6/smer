import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import '../models/smer_entry.dart';

abstract class SmerStore {
  Future<List<SmerEntry>> loadEntries();
  Future<void> saveEntry(SmerEntry entry);
  Future<void> deleteEntry(String id);
  Future<List<CustomEmotion>> loadCustomEmotions();
  Future<void> saveCustomEmotion(CustomEmotion emotion);
  Future<bool> isOnboardingSeen();
  Future<void> markOnboardingSeen();
}

class SqliteSmerStore implements SmerStore {
  SqliteSmerStore({required this.databasePassword});

  final String databasePassword;
  sqlcipher.Database? _database;

  Future<sqlcipher.Database> get _db async {
    if (_database != null) return _database!;
    final encryptedPath = join(await sqlcipher.getDatabasesPath(), 'smer.db');
    _database = await sqlcipher.openDatabase(
      encryptedPath,
      password: databasePassword,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE entries(id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, occurred_at INTEGER NOT NULL, situation TEXT NOT NULL, thoughts TEXT NOT NULL, emotions TEXT NOT NULL, body_reaction TEXT NOT NULL, behavior_reaction TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await _createEmotionCatalog(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createEmotionCatalog(db);
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
    conflictAlgorithm: sqlcipher.ConflictAlgorithm.replace,
  );
  @override
  Future<void> deleteEntry(String id) async =>
      (await _db).delete('entries', where: 'id = ?', whereArgs: [id]);
  @override
  Future<List<CustomEmotion>> loadCustomEmotions() async =>
      (await (await _db).query('custom_emotions', orderBy: 'group_name, name'))
          .map(
            (row) => CustomEmotion(
              name: row['name']! as String,
              group: row['group_name']! as String,
            ),
          )
          .toList();
  @override
  Future<void> saveCustomEmotion(CustomEmotion emotion) async =>
      (await _db).insert('custom_emotions', {
        'name': emotion.name,
        'group_name': emotion.group,
      }, conflictAlgorithm: sqlcipher.ConflictAlgorithm.replace);
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
  }, conflictAlgorithm: sqlcipher.ConflictAlgorithm.replace);

  Future<void> _createEmotionCatalog(sqlcipher.Database db) => db.execute(
    'CREATE TABLE custom_emotions(name TEXT PRIMARY KEY, group_name TEXT NOT NULL)',
  );
}
