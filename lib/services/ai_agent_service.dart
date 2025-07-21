import 'analytics_service.dart';
import 'models/analytics_models.dart';
import 'models/ai_insights.dart';

class AIAgentService {
  final AnalyticsService _analyticsService = AnalyticsService();

  /// 生成综合用户洞察报告
  Future<UserInsightReport> generateUserInsightReport(DateRange dateRange) async {
    // 并行获取各项分析数据
    final results = await Future.wait([
      _analyticsService.getUserRecordStats(dateRange),
      _analyticsService.getMoodTrendAnalysis(dateRange),
      _analyticsService.getUsageBehaviorAnalysis(dateRange),
      _analyticsService.getContentAnalysisInsights(dateRange),
    ]);

    final recordStats = results[0] as UserRecordStats;
    final moodTrend = results[1] as MoodTrendAnalysis;
    final usageBehavior = results[2] as UsageBehaviorAnalysis;
    final contentInsights = results[3] as ContentAnalysisInsights;

    // 生成AI洞察
    final insights = _generateInsights(recordStats, moodTrend, usageBehavior, contentInsights);
    final recommendations = _generateRecommendations(recordStats, moodTrend, usageBehavior, contentInsights);

    return UserInsightReport(
      dateRange: dateRange,
      recordStats: recordStats,
      moodTrend: moodTrend,
      usageBehavior: usageBehavior,
      contentInsights: contentInsights,
      aiInsights: insights,
      recommendations: recommendations,
      generatedAt: DateTime.now(),
    );
  }

  /// 生成AI洞察
  List<AIInsight> _generateInsights(
    UserRecordStats recordStats,
    MoodTrendAnalysis moodTrend,
    UsageBehaviorAnalysis usageBehavior,
    ContentAnalysisInsights contentInsights,
  ) {
    final insights = <AIInsight>[];

    // 记录习惯洞察
    if (recordStats.activityRate >= 0.7) {
      insights.add(AIInsight(
        type: InsightType.positive,
        category: '记录习惯',
        title: '记录习惯优秀',
        description: '您在${recordStats.dateRange.label}保持了${(recordStats.activityRate * 100).toStringAsFixed(0)}%的记录频率，展现出良好的自我管理能力。',
        confidence: 0.9,
      ));
    } else if (recordStats.activityRate < 0.3) {
      insights.add(AIInsight(
        type: InsightType.suggestion,
        category: '记录习惯',
        title: '可以增加记录频率',
        description: '建议设置每日提醒，养成定期记录的习惯，这有助于更好地追踪您的生活状态。',
        confidence: 0.8,
      ));
    }

    // 心情状态洞察
    if (moodTrend.averageMoodIndex >= 7.5) {
      insights.add(AIInsight(
        type: InsightType.positive,
        category: '心情状态',
        title: '心情状态良好',
        description: '您的平均心情指数为${moodTrend.averageMoodIndex.toStringAsFixed(1)}分，整体保持${moodTrend.moodLevel}状态。',
        confidence: 0.9,
      ));
    } else if (moodTrend.averageMoodIndex < 5.0) {
      insights.add(AIInsight(
        type: InsightType.concern,
        category: '心情状态',
        title: '需要关注心情变化',
        description: '最近的心情指数偏低(${moodTrend.averageMoodIndex.toStringAsFixed(1)}分)，建议关注情绪健康，必要时寻求专业帮助。',
        confidence: 0.8,
      ));
    }

    // 使用模式洞察
    if (usageBehavior.mostActiveHour >= 22 || usageBehavior.mostActiveHour <= 6) {
      insights.add(AIInsight(
        type: InsightType.observation,
        category: '使用习惯',
        title: '深夜记录较多',
        description: '您经常在${usageBehavior.mostActiveHour}点记录想法，建议适当调整作息，保证充足睡眠。',
        confidence: 0.7,
      ));
    }

    // 内容质量洞察
    if (contentInsights.averageContentLength >= 150) {
      insights.add(AIInsight(
        type: InsightType.positive,
        category: '记录质量',
        title: '记录内容详细',
        description: '您的记录平均长度为${contentInsights.averageContentLength.toStringAsFixed(0)}字，内容详实，有助于深度反思。',
        confidence: 0.8,
      ));
    }

    return insights;
  }

  /// 生成个性化建议
  List<AIRecommendation> _generateRecommendations(
    UserRecordStats recordStats,
    MoodTrendAnalysis moodTrend,
    UsageBehaviorAnalysis usageBehavior,
    ContentAnalysisInsights contentInsights,
  ) {
    final recommendations = <AIRecommendation>[];

    // 基于活跃度的建议
    if (recordStats.activityRate < 0.5) {
      recommendations.add(AIRecommendation(
        category: '记录习惯',
        title: '设置记录提醒',
        description: '建议在${usageBehavior.mostActiveHourDescription}设置提醒，利用您的活跃时段养成记录习惯。',
        actionType: ActionType.reminder,
        priority: Priority.high,
      ));
    }

    // 基于心情的建议
    if (moodTrend.moodVolatility > 2.0) {
      recommendations.add(AIRecommendation(
        category: '情绪管理',
        title: '关注情绪波动',
        description: '您的心情波动较大，建议记录情绪变化的原因，寻找规律和应对方法。',
        actionType: ActionType.analysis,
        priority: Priority.medium,
      ));
    }

    // 基于使用时间的建议
    if (usageBehavior.mostActiveHour >= 22) {
      recommendations.add(AIRecommendation(
        category: '作息健康',
        title: '调整记录时间',
        description: '建议将记录时间提前到晚上9点前，有助于更好的睡眠质量。',
        actionType: ActionType.schedule,
        priority: Priority.low,
      ));
    }

    // 基于内容的建议
    if (contentInsights.averageContentLength < 50) {
      recommendations.add(AIRecommendation(
        category: '记录质量',
        title: '丰富记录内容',
        description: '尝试记录更多细节，如当时的感受、环境、想法等，这有助于更好地回顾和反思。',
        actionType: ActionType.improvement,
        priority: Priority.medium,
      ));
    }

    return recommendations;
  }

  /// 获取快速洞察摘要
  Future<QuickInsightSummary> getQuickInsightSummary(DateRange dateRange) async {
    final recordStats = await _analyticsService.getUserRecordStats(dateRange);
    final moodTrend = await _analyticsService.getMoodTrendAnalysis(dateRange);

    return QuickInsightSummary(
      totalRecords: recordStats.totalRecords,
      averageMoodIndex: moodTrend.averageMoodIndex,
      moodLevel: moodTrend.moodLevel,
      activityLevel: recordStats.activityLevel,
      dominantMood: moodTrend.dominantMood,
      dateRange: dateRange,
    );
  }

  /// 预测下周记录建议
  Future<List<String>> predictWeeklyGoals(DateRange currentPeriod) async {
    final recordStats = await _analyticsService.getUserRecordStats(currentPeriod);
    final usageBehavior = await _analyticsService.getUsageBehaviorAnalysis(currentPeriod);
    
    final goals = <String>[];
    
    // 基于当前表现预测目标
    if (recordStats.averageDaily < 1.0) {
      goals.add('每天至少记录1条想法');
    } else if (recordStats.averageDaily < 2.0) {
      goals.add('保持每天记录，争取达到2条');
    } else {
      goals.add('继续保持优秀的记录习惯');
    }
    
    // 基于使用时间建议
    goals.add('在${usageBehavior.mostActiveHourDescription}进行深度记录');
    
    // 基于心情建议
    goals.add('记录每日心情变化，关注情绪健康');
    
    return goals;
  }
}