import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/team_member.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('team_management.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // Initialize for web platform
      var databaseFactory = databaseFactoryFfi;
      return await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
        ),
      );
    } else {
      // Initialize for other platforms
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE team_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        timezone TEXT NOT NULL,
        activeHoursStart TEXT NOT NULL,
        activeHoursEnd TEXT NOT NULL,
        extraData TEXT
      )
    ''');
  }

  Future<int> insertMember(TeamMember member) async {
    final db = await database;
    return await db.insert('team_members', member.toMap());
  }

  Future<List<TeamMember>> getAllMembers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('team_members');
    return List.generate(maps.length, (i) => TeamMember.fromMap(maps[i]));
  }

  Future<void> deleteMember(int id) async {
    final db = await database;
    await db.delete(
      'team_members',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
