import 'analytics_models.dart';

/// AI洞察类型
enum InsightType {
  positive,    // 积极洞察
  concern,     // 需要关注
  suggestion,  // 建议
  observation, // 观察发现
}

/// 建议优先级
enum Priority {
  high,
  medium,
  low,
}

/// 行动类型
enum ActionType {
  reminder,    // 设置提醒
  analysis,    // 深度分析
  schedule,    // 时间安排
  improvement, // 改进建议
}

/// AI洞察
class AIInsight {
  final InsightType type;
  final String category;
  final String title;
  final String description;
  final double confidence; // 置信度 0-1

  AIInsight({
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'category': category,
    'title': title,
    'description': description,
    'confidence': confidence,
  };
}

/// AI建议
class AIRecommendation {
  final String category;
  final String title;
  final String description;
  final ActionType actionType;
  final Priority priority;

  AIRecommendation({
    required this.category,
    required this.title,
    required this.description,
    required this.actionType,
    required this.priority,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'title': title,
    'description': description,
    'actionType': actionType.name,
    'priority': priority.name,
  };
}

/// 用户洞察报告
class UserInsightReport {
  final DateRange dateRange;
  final UserRecordStats recordStats;
  final MoodTrendAnalysis moodTrend;
  final UsageBehaviorAnalysis usageBehavior;
  final ContentAnalysisInsights contentInsights;
  final List<AIInsight> aiInsights;
  final List<AIRecommendation> recommendations;
  final DateTime generatedAt;

  UserInsightReport({
    required this.dateRange,
    required this.recordStats,
    required this.moodTrend,
    required this.usageBehavior,
    required this.contentInsights,
    required this.aiInsights,
    required this.recommendations,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'dateRange': dateRange.label,
    'recordStats': recordStats.toJson(),
    'moodTrend': moodTrend.toJson(),
    'usageBehavior': usageBehavior.toJson(),
    'contentInsights': contentInsights.toJson(),
    'aiInsights': aiInsights.map((i) => i.toJson()).toList(),
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
  };
}

/// 快速洞察摘要
class QuickInsightSummary {
  final int totalRecords;
  final double averageMoodIndex;
  final String moodLevel;
  final String activityLevel;
  final String dominantMood;
  final DateRange dateRange;

  QuickInsightSummary({
    required this.totalRecords,
    required this.averageMoodIndex,
    required this.moodLevel,
    required this.activityLevel,
    required this.dominantMood,
    required this.dateRange,
  });

  Map<String, dynamic> toJson() => {
    'totalRecords': totalRecords,
    'averageMoodIndex': averageMoodIndex,
    'moodLevel': moodLevel,
    'activityLevel': activityLevel,
    'dominantMood': dominantMood,
    'dateRange': dateRange.label,
  };
}