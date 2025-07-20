import 'dart:math';
import '../models/note.dart';
import '../database/database_helper.dart';

class MockDataGenerator {
  static final Random _random = Random();
  
  // 心情选项（与应用中定义的一致）
  static final List<String> _moods = [
    '😊开心',
    '😔难过', 
    '😤愤怒',
    '😰焦虑',
    '😴疲惫',
    '😌平静',
    '😍兴奋',
    '🤔思考',
  ];

  // 模拟记录内容模板
  static final List<String> _contentTemplates = [
    // 工作相关
    '今天的会议讨论了新项目的进展，感觉团队合作很顺利',
    '完成了一个重要的任务，虽然过程有些挑战但结果不错',
    '和同事讨论技术方案，学到了很多新的思路',
    '项目deadline临近，压力有点大但还是要坚持',
    '今天工作效率很高，提前完成了计划的任务',
    '遇到了一个技术难题，需要继续研究解决方案',
    '团队聚餐很开心，同事们都很友善',
    '加班到很晚，但看到项目进展还是很有成就感',
    
    // 学习相关
    '今天学习了新的知识点，感觉很有收获',
    '看完了一本很有启发的书，记录一些感想',
    '参加了线上课程，老师讲得很生动有趣',
    '复习了之前的笔记，发现还有很多需要加强的地方',
    '和朋友讨论学习心得，互相分享了很多经验',
    '制定了新的学习计划，希望能够坚持执行',
    '今天的学习状态不太好，需要调整一下方法',
    '完成了一个小项目，对自己的能力更有信心了',
    
    // 生活感悟
    '今天天气很好，心情也跟着明朗起来',
    '和家人通了电话，感受到了温暖的关怀',
    '散步时看到了美丽的夕阳，生活中的小美好',
    '今天有点累，但还是要保持积极的心态',
    '思考了一些人生的问题，感觉有了新的理解',
    '和老朋友聚会，回忆起了很多美好的时光',
    '尝试了新的菜谱，烹饪过程很有趣',
    '看了一部很棒的电影，被故事深深感动',
    '今天的运动让我感觉很有活力',
    '整理房间时发现了一些珍贵的回忆',
    
    // 情感表达
    '今天心情特别好，想要记录下这份快乐',
    '遇到了一些挫折，但相信明天会更好',
    '感谢生活中遇到的每一个善良的人',
    '今天有些焦虑，需要找到放松的方法',
    '完成了一个小目标，给自己一个鼓励',
    '思考了很多，感觉内心更加平静了',
    '今天的经历让我成长了不少',
    '希望能够保持现在这种积极的状态',
    
    // 日常记录
    '早上的咖啡特别香，开启了美好的一天',
    '地铁上看到了有趣的事情，想要记录下来',
    '午餐时间和同事聊天，了解了不同的观点',
    '下班路上的风景很美，让人心情愉悦',
    '晚上读书的时光很安静，很享受这种感觉',
    '今天的天气变化很大，提醒自己要注意身体',
    '购物时发现了很多有趣的商品',
    '和宠物玩耍的时间总是很快乐',
    '今天做了一些家务，看到整洁的环境很满足',
    '睡前回想今天的经历，感觉很充实',
  ];

  /// 生成模拟测试数据
  static Future<void> generateMockData({int totalRecords = 100}) async {
    final dbHelper = DatabaseHelper();
    final now = DateTime.now();
    
    print('开始生成 $totalRecords 条模拟数据...');
    
    for (int day = 6; day >= 0; day--) {
      // 每天生成5-20条记录
      final recordsPerDay = 5 + _random.nextInt(16);
      final targetDate = now.subtract(Duration(days: day));
      
      print('生成第 ${7-day} 天的数据: ${recordsPerDay} 条记录');
      
      for (int i = 0; i < recordsPerDay; i++) {
        // 随机选择时间点（8:00-23:00）
        final hour = 8 + _random.nextInt(16);
        final minute = _random.nextInt(60);
        final second = _random.nextInt(60);
        
        final recordTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
          second,
        );
        
        // 随机选择内容和心情
        final content = _contentTemplates[_random.nextInt(_contentTemplates.length)];
        final mood = _moods[_random.nextInt(_moods.length)];
        
        // 创建记录
        final note = Note(
          content: content,
          createdAt: recordTime,
          updatedAt: recordTime,
          mood: mood,
        );
        
        try {
          await dbHelper.insertNote(note);
        } catch (e) {
          print('插入数据失败: $e');
        }
      }
    }
    
    print('模拟数据生成完成！');
  }

  /// 清除所有测试数据
  static Future<void> clearAllData() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    
    await db.delete('notes');
    print('所有数据已清除');
  }

  /// 生成特定日期的数据
  static Future<void> generateDataForDate(DateTime date, int count) async {
    final dbHelper = DatabaseHelper();
    
    for (int i = 0; i < count; i++) {
      final hour = 8 + _random.nextInt(16);
      final minute = _random.nextInt(60);
      
      final recordTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      
      final content = _contentTemplates[_random.nextInt(_contentTemplates.length)];
      final mood = _moods[_random.nextInt(_moods.length)];
      
      final note = Note(
        content: content,
        createdAt: recordTime,
        updatedAt: recordTime,
        mood: mood,
      );
      
      await dbHelper.insertNote(note);
    }
  }

  /// 获取数据统计信息
  static Future<Map<String, dynamic>> getDataStats() async {
    final dbHelper = DatabaseHelper();
    final allNotes = await dbHelper.getAllNotes();
    
    final moodCounts = <String, int>{};
    final dateCounts = <String, int>{};
    
    for (final note in allNotes) {
      // 统计心情分布
      if (note.mood != null) {
        moodCounts[note.mood!] = (moodCounts[note.mood!] ?? 0) + 1;
      }
      
      // 统计日期分布
      final dateKey = '${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}-${note.createdAt.day.toString().padLeft(2, '0')}';
      dateCounts[dateKey] = (dateCounts[dateKey] ?? 0) + 1;
    }
    
    return {
      'totalRecords': allNotes.length,
      'moodDistribution': moodCounts,
      'dateDistribution': dateCounts,
      'dateRange': allNotes.isNotEmpty ? {
        'earliest': allNotes.last.createdAt,
        'latest': allNotes.first.createdAt,
      } : null,
    };
  }
}