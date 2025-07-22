import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/examples/ai_agent_usage_example.dart';
import '../utils/mood_scoring.dart';
import '../services/ai_agent_service.dart';
import '../services/models/analytics_models.dart';
import '../services/models/ai_insights.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '本月';
  Map<String, int> _moodStats = {};
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _moodIndexStats = []; // 新增心情指数数据
  bool _isLoading = true;
  final AIAgentService _aiAgent = AIAgentService();
  QuickInsightSummary? _quickSummary;

  final List<String> _periods = ['本周', '本月', '全部'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 增加AI洞察标签页
    _loadAnalyticsData();
    _loadAIInsights(); // 加载AI洞察
    _init();
  }
  Future<void> _init()async{
    final example = AIAgentUsageExample();

    // 运行各种示例
    await example.exampleGetMonthlyReport();
    await example.exampleGetQuickSummary();
    await example.exampleGetWeeklyGoals();
    await example.exampleCustomDateRange();
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadMoodStats(),
        _loadDailyStats(),
        _loadMoodIndexStats(), // 新增心情指数数据加载
      ]);
    } catch (e) {
      print('加载统计数据失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoodStats() async {
    final stats = await DatabaseHelper().getMoodStatistics(_getDateRange());
    setState(() => _moodStats = stats);
  }

  Future<void> _loadDailyStats() async {
    final stats = await DatabaseHelper().getDailyStatistics(_getDateRange());
    setState(() => _dailyStats = stats);
  }

  Future<void> _loadMoodIndexStats() async {
    final stats = await DatabaseHelper().getDailyMoodIndex(_getDateRange());
    setState(() => _moodIndexStats = stats);
  }

  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedPeriod) {
      case '本周':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case '本月':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(2020, 1, 1);
    }
    
    return {'start': startDate, 'end': now};
  }

  DateRange _getDateRangeObject() {
    switch (_selectedPeriod) {
      case '本周':
        return DateRange.thisWeek();
      case '本月':
        return DateRange.thisMonth();
      default:
        return DateRange.all();
    }
  }

  Future<void> _loadAIInsights() async {
    try {
      final dateRange = _getDateRangeObject();
      final summary = await _aiAgent.getQuickInsightSummary(dateRange);
      setState(() => _quickSummary = summary);
    } catch (e) {
      print('加载AI洞察失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F8F2),
      appBar: AppBar(
        title: const Text('数据统计'),
        backgroundColor: const Color(0xFF31DA9F),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '心情分析'), // 合并心情分布和心情指数趋势
            Tab(text: '使用统计'),
            Tab(text: 'AI洞察'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF31DA9F)),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMoodAnalysis(), // 新的心情分析页面
                      _buildUsageStats(),
                      _buildAIInsights(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('时间范围：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(period),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPeriod = period);
                          _loadAnalyticsData();
                        }
                      },
                      selectedColor: const Color(0xFF31DA9F),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCountChart() {
    if (_dailyStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('记录数量趋势', 
                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Expanded(
                child: Center(child: Text('暂无数据')),
              ),
            ],
          ),
        ),
      );
    }

    // 直接在这里计算间隔
    double getInterval() {
      final dataCount = _dailyStats.length;
      if (dataCount <= 7) {
        return 1;
      } else if (dataCount <= 14) {
        return 2;
      } else if (dataCount <= 30) {
        return 3;
      } else {
        return (dataCount / 8).ceil().toDouble();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('记录数量趋势 (${_dailyStats.length}天)', 
                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 25,
                        interval: getInterval(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _dailyStats.length) {
                            final date = DateTime.parse(_dailyStats[index]['date']);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('MM/dd').format(date),
                                style: const TextStyle(fontSize: 9),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _dailyStats.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value['count'].toDouble());
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF31DA9F),
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF31DA9F).withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodIndexChart() {
    if (_moodIndexStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('心情指数趋势', 
                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('暂无心情数据', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 计算间隔
    double getInterval() {
      final dataCount = _moodIndexStats.length;
      if (dataCount <= 7) {
        return 1;
      } else if (dataCount <= 14) {
        return 2;
      } else if (dataCount <= 30) {
        return 3;
      } else {
        return (dataCount / 8).ceil().toDouble();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('心情指数趋势 (${_moodIndexStats.length}天)', 
                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, 
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 25,
                        interval: getInterval(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _moodIndexStats.length) {
                            final date = DateTime.parse(_moodIndexStats[index]['date']);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('MM/dd').format(date),
                                style: const TextStyle(fontSize: 9),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 1,
                  maxY: 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _moodIndexStats.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value['mood_index'].toDouble());
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF31DA9F),
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF31DA9F).withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodChart() {
    if (_moodStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('心情分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Expanded(
                child: Center(child: Text('暂无心情数据')),
              ),
            ],
          ),
        ),
      );
    }

    final total = _moodStats.values.reduce((a, b) => a + b);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('心情分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: _moodStats.entries.map((entry) {
                          final percentage = (entry.value / total * 100);
                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            title: '${percentage.toStringAsFixed(1)}%',
                            color: _getMoodColor(entry.key),
                            radius: 60, // 稍微缩小半径
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        centerSpaceRadius: 30, // 缩小中心空间
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _moodStats.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getMoodColor(entry.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${entry.key.substring(2)} (${entry.value})',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStats() {
    final totalNotes = _dailyStats.fold<int>(0, (sum, item) => sum + (item['count'] as int));
    final avgDaily = _dailyStats.isNotEmpty ? (totalNotes / _dailyStats.length).toStringAsFixed(1) : '0';
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 统计卡片
          Row(
            children: [
              Expanded(child: _buildStatCard('总记录数', totalNotes.toString(), Icons.note_alt)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('日均记录', avgDaily, Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard('心情种类', _moodStats.length.toString(), Icons.mood),
          const SizedBox(height: 16),
          // 记录数量趋势图
          Expanded(
            child: _buildRecordCountChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF31DA9F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF31DA9F), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 心情分布饼图
          Expanded(
            flex: 1,
            child: _buildMoodChart(),
          ),
          const SizedBox(height: 16),
          // 心情指数趋势图
          Expanded(
            flex: 1,
            child: _buildMoodIndexChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsights() {
    if (_quickSummary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInsightCard('总体评估', _quickSummary!.activityLevel, Icons.assessment),
          const SizedBox(height: 12),
          _buildInsightCard('心情状态', _quickSummary!.moodLevel, Icons.mood),
          const SizedBox(height: 12),
          _buildInsightCard('主要心情', _quickSummary!.dominantMood, Icons.favorite),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showDetailedReport,
            icon: const Icon(Icons.analytics),
            label: const Text('查看详细分析报告'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF31DA9F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF31DA9F)),
        title: Text(title),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _showDetailedReport() async {
    // 显示详细的AI分析报告
    // 可以导航到新页面或显示对话框
  }

  Color _getMoodColor(String mood) {
    final colors = [
      const Color(0xFF31DA9F), // 主青绿色
      const Color(0xFF28B085), // 深青绿
      const Color(0xFF7AE6B8), // 浅青绿
      const Color(0xFF52E5A3), // 中青绿
      const Color(0xFF1ABC9C), // 蓝绿
      const Color(0xFF16A085), // 深蓝绿
      const Color(0xFF48C9B0), // 浅蓝绿
      const Color(0xFF58D68D), // 绿色
    ];
    return colors[mood.hashCode % colors.length];
  }
}
