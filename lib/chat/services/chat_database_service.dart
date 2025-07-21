import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';
import '../../database/database_helper.dart';

class ChatDatabaseService {
  static const String tableName = 'chat_messages';

  /// 创建聊天消息表
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        message_type TEXT DEFAULT 'text',
        metadata TEXT
      )
    ''');
  }

  /// 保存聊天消息
  Future<int> insertMessage(ChatMessage message) async {
    final db = await DatabaseHelper().database;
    return await db.insert(tableName, message.toMap());
  }

  /// 获取所有聊天记录
  Future<List<ChatMessage>> getAllMessages() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return ChatMessage.fromMap(maps[i]);
    });
  }

  /// 获取最近的聊天记录
  Future<List<ChatMessage>> getRecentMessages({int limit = 50}) async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return ChatMessage.fromMap(maps[i]);
    }).reversed.toList();
  }

  /// 清空聊天记录
  Future<void> clearAllMessages() async {
    final db = await DatabaseHelper().database;
    await db.delete(tableName);
  }

  /// 删除指定消息
  Future<void> deleteMessage(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}