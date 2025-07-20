import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';
import '../utils/mood_scoring.dart';
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'voca_notes.db');
    return await openDatabase(
      path,
      version: 3, // 升级版本号
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        mood TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN mood TEXT');
    }
    if (oldVersion < 3) {
      // 移除标签字段（SQLite不支持DROP COLUMN，所以保持现有结构）
      // 新记录不会使用tags字段
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // 新增：按日期查询记录
  Future<List<Note>> getNotesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // 新增：按日期和心情查询记录
  Future<List<Note>> getNotesByDateAndMood(DateTime date, String? mood) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    String whereClause = 'created_at >= ? AND created_at <= ?';
    List<dynamic> whereArgs = [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch];
    
    if (mood != null) {
      whereClause += ' AND mood = ?';
      whereArgs.add(mood);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // 新增：按日期范围查询记录
  Future<List<Note>> getNotesByDateRange(DateTime startDate, DateTime endDate, String? mood) async {
    final db = await database;
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    
    String whereClause = 'created_at >= ? AND created_at <= ?';
    List<dynamic> whereArgs = [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch];
    
    if (mood != null) {
      whereClause += ' AND mood = ?';
      whereArgs.add(mood);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 获取指定日期范围内每日的记录数量
  Future<Map<DateTime, int>> getNoteCountsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    
    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        DATE(created_at / 1000, 'unixepoch') as date, 
        COUNT(*) as count
      FROM notes 
      WHERE created_at >= ? AND created_at <= ?
      GROUP BY DATE(created_at / 1000, 'unixepoch')
    ''', [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);
    
    final Map<DateTime, int> result = {};
    
    for (final map in maps) {
      final dateStr = map['date'] as String;
      final count = map['count'] as int;
      final date = DateTime.parse(dateStr);
      // 标准化日期，只保留年月日
      final normalizedDate = DateTime(date.year, date.month, date.day);
      result[normalizedDate] = count;
    }
    
    return result;
  }

  // 获取心情统计数据
  Future<Map<String, int>> getMoodStatistics(Map<String, DateTime> dateRange) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT mood, COUNT(*) as count
      FROM notes 
      WHERE mood IS NOT NULL 
        AND created_at >= ? 
        AND created_at <= ?
      GROUP BY mood
      ORDER BY count DESC
    ''', [
      dateRange['start']!.millisecondsSinceEpoch,
      dateRange['end']!.millisecondsSinceEpoch,
    ]);
    
    final Map<String, int> result = {};
    for (final map in maps) {
      result[map['mood'] as String] = map['count'] as int;
    }
    
    return result;
  }

  // 获取每日统计数据
  Future<List<Map<String, dynamic>>> getDailyStatistics(Map<String, DateTime> dateRange) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        DATE(created_at / 1000, 'unixepoch') as date,
        COUNT(*) as count
      FROM notes 
      WHERE created_at >= ? AND created_at <= ?
      GROUP BY DATE(created_at / 1000, 'unixepoch')
      ORDER BY date ASC
    ''', [
      dateRange['start']!.millisecondsSinceEpoch,
      dateRange['end']!.millisecondsSinceEpoch,
    ]);
    
    return maps;
  }

  // 获取每日心情指数统计
  Future<List<Map<String, dynamic>>> getDailyMoodIndex(Map<String, DateTime> dateRange) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        DATE(created_at / 1000, 'unixepoch') as date,
        mood
      FROM notes 
      WHERE mood IS NOT NULL 
        AND created_at >= ? 
        AND created_at <= ?
      ORDER BY date ASC
    ''', [
      dateRange['start']!.millisecondsSinceEpoch,
      dateRange['end']!.millisecondsSinceEpoch,
    ]);
    
    // 按日期分组并计算每日平均心情指数
    final Map<String, List<int>> dailyMoodScores = {};
    
    for (final map in maps) {
      final date = map['date'] as String;
      final mood = map['mood'] as String;
      final score = MoodScoring.getMoodScore(mood);
      
      if (!dailyMoodScores.containsKey(date)) {
        dailyMoodScores[date] = [];
      }
      dailyMoodScores[date]!.add(score);
    }
    
    // 计算每日平均分并转换为结果格式
    final List<Map<String, dynamic>> result = [];
    
    for (final entry in dailyMoodScores.entries) {
      final averageScore = MoodScoring.calculateAverageScore(entry.value);
      result.add({
        'date': entry.key,
        'mood_index': averageScore,
        'record_count': entry.value.length,
      });
    }
    
    return result;
  }
}
