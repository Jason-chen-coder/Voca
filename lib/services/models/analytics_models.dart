import 'dart:math';

/// 日期范围类
class DateRange {
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  DateRange({
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  int get dayCount => endDate.difference(startDate).inDays + 1;

  /// 创建预设的日期范围
  static DateRange thisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return DateRange(
      startDate: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      endDate: DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59),
      label: '本周',
    );
  }

  static DateRange thisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    return DateRange(
      startDate: startOfMonth,
      endDate: endOfMonth,
      label: '本月',
    );
  }

  static DateRange all() {
    return DateRange(
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime.now(),
      label: '全部',
    );
  }
}

/// 用户记录统计数据
class UserRecordStats {
  final int totalRecords;
  final double averageDaily;
  final int activeDays;
  final int totalDays;
  final int moodVariety;
  final DateRange dateRange;
  final Map<DateTime, int> dailyDistribution;

  UserRecordStats({
    required this.totalRecords,
    required this.averageDaily,
    required this.activeDays,
    required this.totalDays,
    required this.moodVariety,
    required this.dateRange,
    required this.dailyDistribution,
  });

  double get activityRate => totalDays > 0 ? activeDays / totalDays : 0.0;
  
  String get activityLevel {
    if (activityRate >= 0.8) return '非常活跃';
    if (activityRate >= 0.6) return '活跃';
    if (activityRate >= 0.4) return '一般';
    if (activityRate >= 0.2) return '较少';
    return '很少';
  }

  Map<String, dynamic> toJson() => {
    'totalRecords': totalRecords,
    'averageDaily': averageDaily,
    'activeDays': activeDays,
    'totalDays': totalDays,
    'moodVariety': moodVariety,
    'activityRate': activityRate,
    'activityLevel': activityLevel,
    'dateRange': dateRange.label,
  };
}

/// 心情趋势分析
class MoodTrendAnalysis {
  final double averageMoodIndex;
  final String moodLevel;
  final double moodVolatility;
  final Map<String, int> moodDistribution;
  final List<Map<String, dynamic>> dailyMoodIndex;
  final DateRange dateRange;

  MoodTrendAnalysis({
    required this.averageMoodIndex,
    required this.moodLevel,
    required this.moodVolatility,
    required this.moodDistribution,
    required this.dailyMoodIndex,
    required this.dateRange,
  });

  String get volatilityLevel {
    if (moodVolatility <= 1.0) return '稳定';
    if (moodVolatility <= 2.0) return '轻微波动';
    if (moodVolatility <= 3.0) return '中等波动';
    return '波动较大';
  }

  String get dominantMood {
    if (moodDistribution.isEmpty) return '无数据';
    return moodDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  Map<String, dynamic> toJson() => {
    'averageMoodIndex': averageMoodIndex,
    'moodLevel': moodLevel,
    'moodVolatility': moodVolatility,
    'volatilityLevel': volatilityLevel,
    'dominantMood': dominantMood,
    'moodDistribution': moodDistribution,
    'dateRange': dateRange.label,
  };
}

/// 使用行为分析
class UsageBehaviorAnalysis {
  final int totalRecords;
  final double averageRecordsPerDay;
  final int mostActiveHour;
  final int mostActiveWeekday;
  final Map<int, int> hourlyDistribution;
  final Map<int, int> weekdayDistribution;
  final DateRange dateRange;

  UsageBehaviorAnalysis({
    required this.totalRecords,
    required this.averageRecordsPerDay,
    required this.mostActiveHour,
    required this.mostActiveWeekday,
    required this.hourlyDistribution,
    required this.weekdayDistribution,
    required this.dateRange,
  });

  String get mostActiveHourDescription {
    if (mostActiveHour >= 6 && mostActiveHour < 12) return '上午时段';
    if (mostActiveHour >= 12 && mostActiveHour < 18) return '下午时段';
    if (mostActiveHour >= 18 && mostActiveHour < 22) return '晚上时段';
    return '深夜时段';
  }

  String get mostActiveWeekdayDescription {
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[mostActiveWeekday];
  }


  Map<String, dynamic> toJson() => {
    'totalRecords': totalRecords,
    'averageRecordsPerDay': averageRecordsPerDay,
    'mostActiveHour': mostActiveHour,
    'mostActiveHourDescription': mostActiveHourDescription,
    'mostActiveWeekday': mostActiveWeekday,
    'mostActiveWeekdayDescription': mostActiveWeekdayDescription,
    'dateRange': dateRange.label,
  };
}

/// 内容分析洞察
class ContentAnalysisInsights {
  final int totalRecords;
  final double averageContentLength;
  final Map<String, int> topKeywords;
  final Map<String, int> contentLengthDistribution;
  final DateRange dateRange;

  ContentAnalysisInsights({
    required this.totalRecords,
    required this.averageContentLength,
    required this.topKeywords,
    required this.contentLengthDistribution,
    required this.dateRange,
  });

  String get contentLengthLevel {
    if (averageContentLength >= 200) return '详细记录';
    if (averageContentLength >= 100) return '中等详细';
    if (averageContentLength >= 50) return '简洁记录';
    return '极简记录';
  }

  Map<String, dynamic> toJson() => {
    'totalRecords': totalRecords,
    'averageContentLength': averageContentLength,
    'contentLengthLevel': contentLengthLevel,
    'topKeywords': topKeywords,
    'contentLengthDistribution': contentLengthDistribution,
    'dateRange': dateRange.label,
  };
}