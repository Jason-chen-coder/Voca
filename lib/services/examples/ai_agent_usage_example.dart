import '../ai_agent_service.dart';
import '../models/analytics_models.dart';

class AIAgentUsageExample {
  final AIAgentService _aiAgent = AIAgentService();

  /// 示例1: 获取本月用户洞察报告
  Future<void> exampleGetMonthlyReport() async {
    try {
      final dateRange = DateRange.thisMonth();
      final report = await _aiAgent.generateUserInsightReport(dateRange);
      
      print('=== 用户洞察报告 ===');
      print('时间范围: ${report.dateRange.label}');
      print('总记录数: ${report.recordStats.totalRecords}');
      print('平均心情指数: ${report.moodTrend.averageMoodIndex.toStringAsFixed(1)}');
      print('活跃度: ${report.recordStats.activityLevel}');
      
      print('\n=== AI洞察 ===');
      for (final insight in report.aiInsights) {
        print('${insight.category}: ${insight.title}');
        print('  ${insight.description}');
        print('  置信度: ${(insight.confidence * 100).toStringAsFixed(0)}%\n');
      }
      
      print('=== 个性化建议 ===');
      for (final recommendation in report.recommendations) {
        print('${recommendation.category}: ${recommendation.title}');
        print('  ${recommendation.description}');
        print('  优先级: ${recommendation.priority.name}\n');
      }
      
    } catch (e) {
      print('获取报告失败: $e');
    }
  }

  /// 示例2: 获取快速洞察摘要
  Future<void> exampleGetQuickSummary() async {
    try {
      final dateRange = DateRange.thisWeek();
      final summary = await _aiAgent.getQuickInsightSummary(dateRange);
      
      print('=== 本周快速摘要 ===');
      print('记录总数: ${summary.totalRecords}');
      print('心情状态: ${summary.moodLevel}');
      print('活跃程度: ${summary.activityLevel}');
      print('主要心情: ${summary.dominantMood}');
      
    } catch (e) {
      print('获取摘要失败: $e');
    }
  }

  /// 示例3: 获取下周目标建议
  Future<void> exampleGetWeeklyGoals() async {
    try {
      final currentWeek = DateRange.thisWeek();
      final goals = await _aiAgent.predictWeeklyGoals(currentWeek);
      
      print('=== 下周建议目标 ===');
      for (int i = 0; i < goals.length; i++) {
        print('${i + 1}. ${goals[i]}');
      }
      
    } catch (e) {
      print('获取目标建议失败: $e');
    }
  }

  /// 示例4: 自定义日期范围分析
  Future<void> exampleCustomDateRange() async {
    try {
      final customRange = DateRange(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        label: '最近30天',
      );
      
      final report = await _aiAgent.generateUserInsightReport(customRange);
      
      // 输出JSON格式数据（便于API调用）
      final jsonData = report.toJson();
      print('=== JSON格式报告 ===');
      print(jsonData);
      
    } catch (e) {
      print('自定义分析失败: $e');
    }
  }
}

/// 在页面中使用示例
void main() async {
  final example = AIAgentUsageExample();
  
  // 运行各种示例
  await example.exampleGetMonthlyReport();
  await example.exampleGetQuickSummary();
  await example.exampleGetWeeklyGoals();
  await example.exampleCustomDateRange();
}