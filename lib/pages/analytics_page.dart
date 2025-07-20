import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/note.dart';

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
  bool _isLoading = true;

  final List<String> _periods = ['本周', '本月', '全部'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalyticsData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('数据统计'),
        backgroundColor: const Color(0xFF8BC34A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '记录趋势'),
            Tab(text: '心情分布'),
            Tab(text: '使用统计'),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8BC34A)),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTrendChart(),
                      _buildMoodChart(),
                      _buildUsageStats(),
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
                      selectedColor: const Color(0xFF8BC34A),
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

  Widget _buildTrendChart() {
    if (_dailyStats.isEmpty) {
      return const Center(child: Text('暂无数据'));
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

    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('记录数量趋势 (${_dailyStats.length}天)', 
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
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
                          reservedSize: 30,
                          interval: getInterval(),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < _dailyStats.length) {
                              final date = DateTime.parse(_dailyStats[index]['date']);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MM/dd').format(date),
                                  style: const TextStyle(fontSize: 10),
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
                        color: const Color(0xFF8BC34A),
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF8BC34A).withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodChart() {
    if (_moodStats.isEmpty) {
      return const Center(child: Text('暂无心情数据'));
    }

    final total = _moodStats.values.reduce((a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('心情分布', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
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
                              radius: 80,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _moodStats.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _getMoodColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${entry.key.substring(2)} (${entry.value})',
                                    style: const TextStyle(fontSize: 12),
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
          _buildStatCard('总记录数', totalNotes.toString(), Icons.note_alt),
          const SizedBox(height: 12),
          _buildStatCard('日均记录', avgDaily, Icons.trending_up),
          const SizedBox(height: 12),
          _buildStatCard('心情种类', _moodStats.length.toString(), Icons.mood),
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
                color: const Color(0xFF8BC34A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF8BC34A), size: 24),
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

  Color _getMoodColor(String mood) {
    final colors = [
      const Color(0xFF8BC34A), // 绿色
      const Color(0xFF4CAF50), // 深绿
      const Color(0xFFFFC107), // 黄色
      const Color(0xFFFF9800), // 橙色
      const Color(0xFFF44336), // 红色
      const Color(0xFF9C27B0), // 紫色
      const Color(0xFF2196F3), // 蓝色
      const Color(0xFF607D8B), // 蓝灰
    ];
    return colors[mood.hashCode % colors.length];
  }
}
