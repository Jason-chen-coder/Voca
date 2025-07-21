

import 'dart:math';
import '../database/database_helper.dart';
import '../utils/mood_scoring.dart';
import 'models/analytics_models.dart';

class AnalyticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 获取用户记录统计数据
  Future<UserRecordStats> getUserRecordStats(DateRange dateRange) async {
    final notes = await _dbHelper.getNotesByDateRange(
      dateRange.startDate, 
      dateRange.endDate, 
      null
    );
    
    final dailyCounts = await _dbHelper.getNoteCountsByDateRange(
      dateRange.startDate, 
      dateRange.endDate
    );
    
    final moodStats = await _dbHelper.getMoodStatistics({
      'start': dateRange.startDate,
      'end': dateRange.endDate,
    });

    return UserRecordStats(
      totalRecords: notes.length,
      averageDaily: notes.isNotEmpty ? notes.length / dateRange.dayCount : 0.0,
      activeDays: dailyCounts.length,
      totalDays: dateRange.dayCount,
      moodVariety: moodStats.length,
      dateRange: dateRange,
      dailyDistribution: dailyCounts,
    );
  }

  /// 获取心情趋势分析
  Future<MoodTrendAnalysis> getMoodTrendAnalysis(DateRange dateRange) async {
    final moodIndexStats = await _dbHelper.getDailyMoodIndex({
      'start': dateRange.startDate,
      'end': dateRange.endDate,
    });
    
    final moodStats = await _dbHelper.getMoodStatistics({
      'start': dateRange.startDate,
      'end': dateRange.endDate,
    });

    // 计算心情指数统计
    final moodScores = moodIndexStats
        .map((stat) => stat['mood_index'] as double)
        .toList();
    
    double averageMoodIndex = 0.0;
    double moodVolatility = 0.0;
    
    if (moodScores.isNotEmpty) {
      averageMoodIndex = moodScores.reduce((a, b) => a + b) / moodScores.length;
      
      // 计算波动性（标准差）
      final variance = moodScores
          .map((score) => (score - averageMoodIndex) * (score - averageMoodIndex))
          .reduce((a, b) => a + b) / moodScores.length;
      moodVolatility = variance > 0 ? sqrt(variance) : 0.0;
    }

    return MoodTrendAnalysis(
      averageMoodIndex: averageMoodIndex,
      moodLevel: MoodScoring.getMoodLevel(averageMoodIndex),
      moodVolatility: moodVolatility,
      moodDistribution: moodStats,
      dailyMoodIndex: moodIndexStats,
      dateRange: dateRange,
    );
  }

  /// 获取使用行为分析
  Future<UsageBehaviorAnalysis> getUsageBehaviorAnalysis(DateRange dateRange) async {
    final notes = await _dbHelper.getNotesByDateRange(
      dateRange.startDate, 
      dateRange.endDate, 
      null
    );
    
    // 分析活跃时段
    final hourlyStats = <int, int>{};
    final weekdayStats = <int, int>{};
    
    for (final note in notes) {
      final hour = note.createdAt.hour;
      final weekday = note.createdAt.weekday;
      
      hourlyStats[hour] = (hourlyStats[hour] ?? 0) + 1;
      weekdayStats[weekday] = (weekdayStats[weekday] ?? 0) + 1;
    }
    
    // 找出最活跃时段
    final mostActiveHour = hourlyStats.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    final mostActiveWeekday = weekdayStats.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return UsageBehaviorAnalysis(
      totalRecords: notes.length,
      averageRecordsPerDay: notes.length / dateRange.dayCount,
      mostActiveHour: mostActiveHour,
      mostActiveWeekday: mostActiveWeekday,
      hourlyDistribution: hourlyStats,
      weekdayDistribution: weekdayStats,
      dateRange: dateRange,
    );
  }

  /// 获取内容分析洞察
  Future<ContentAnalysisInsights> getContentAnalysisInsights(DateRange dateRange) async {
    final notes = await _dbHelper.getNotesByDateRange(
      dateRange.startDate, 
      dateRange.endDate, 
      null
    );
    
    // 分析内容长度分布
    final contentLengths = notes.map((note) => note.content.length).toList();
    final averageLength = contentLengths.isNotEmpty 
        ? contentLengths.reduce((a, b) => a + b) / contentLengths.length 
        : 0.0;
    
    // 分析关键词频率（简单实现）
    final wordFrequency = <String, int>{};
    for (final note in notes) {
      final words = note.content.split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length > 2) { // 过滤短词
          wordFrequency[word] = (wordFrequency[word] ?? 0) + 1;
        }
      }
    }
    
    // 获取高频词汇
    final topWords = wordFrequency.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(10);

    return ContentAnalysisInsights(
      totalRecords: notes.length,
      averageContentLength: averageLength,
      topKeywords: Map.fromEntries(topWords),
      contentLengthDistribution: _calculateLengthDistribution(contentLengths),
      dateRange: dateRange,
    );
  }

  /// 计算内容长度分布
  Map<String, int> _calculateLengthDistribution(List<int> lengths) {
    final distribution = <String, int>{
      '短文本(0-50字)': 0,
      '中等(51-150字)': 0,
      '长文本(151-300字)': 0,
      '超长(300字以上)': 0,
    };
    
    for (final length in lengths) {
      if (length <= 50) {
        distribution['短文本(0-50字)'] = distribution['短文本(0-50字)']! + 1;
      } else if (length <= 150) {
        distribution['中等(51-150字)'] = distribution['中等(51-150字)']! + 1;
      } else if (length <= 300) {
        distribution['长文本(151-300字)'] = distribution['长文本(151-300字)']! + 1;
      } else {
        distribution['超长(300字以上)'] = distribution['超长(300字以上)']! + 1;
      }
    }
    
    return distribution;
  }
}
