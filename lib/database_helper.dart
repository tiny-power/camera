import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await initDb();
    return _database!;
  }

  Future<Database> initDb() async {
    var db = await openDatabase('camera.db');
    try {
      await db.execute(
        'CREATE TABLE Rewarder (id INTEGER PRIMARY KEY, record_time TIMESTAMP, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)',
      );
    } catch (e) {
      e.toString();
    }
    return db;
  }
}
