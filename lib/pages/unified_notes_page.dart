import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:voca/pages/deepseek_settings_page.dart';
import '../models/note.dart';
import '../database/database_helper.dart';
import 'add_note_page.dart';
import 'analytics_page.dart';  // 添加导入
import 'package:flutter/foundation.dart';
import 'debug_page.dart';  // 添加导入
import '../chat/pages/chat_page.dart';

class UnifiedNotesPage extends StatefulWidget {
  const UnifiedNotesPage({super.key});

  @override
  State<UnifiedNotesPage> createState() => _UnifiedNotesPageState();
}

class _UnifiedNotesPageState extends State<UnifiedNotesPage>
    with TickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  List<Note> _notes = [];
  bool _isLoading = false;
  String? _selectedMood;
  Map<DateTime, int> _noteCounts = {}; // 存储每日记录数量

  // 动画控制器
  late AnimationController _listAnimationController;
  late AnimationController _moodFilterController;
  late AnimationController _staggeredController;
  
  // 动画
  late Animation<double> _listFadeAnimation;
  late Animation<Offset> _listSlideAnimation;
  
  // 预设心情选项
  final List<Map<String, String>> _moodOptions = [
    {'emoji': '😊', 'label': '开心'},
    {'emoji': '😔', 'label': '难过'},
    {'emoji': '😤', 'label': '愤怒'},
    {'emoji': '😰', 'label': '焦虑'},
    {'emoji': '😴', 'label': '疲惫'},
    {'emoji': '😌', 'label': '平静'},
    {'emoji': '😍', 'label': '兴奋'},
    {'emoji': '🤔', 'label': '思考'},
  ];

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _moodFilterController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _staggeredController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // 初始化动画
    _listFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _listSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadNotesForSelectedDay();
    _loadNoteCountsForMonth(); // 加载当月记录数量
  }

  // 加载当月每日记录数量
  Future<void> _loadNoteCountsForMonth() async {
    try {
      final firstDay = DateTime(_selectedDay.year, _selectedDay.month, 1);
      final lastDay = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
      
      final counts = await DatabaseHelper().getNoteCountsByDateRange(firstDay, lastDay);
      
      setState(() {
        _noteCounts = counts;
      });
    } catch (e) {
      print('加载记录数量失败: $e');
    }
  }

  // 获取指定日期的记录数量
  int _getNoteCountForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _noteCounts[normalizedDay] ?? 0;
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _moodFilterController.dispose();
    _staggeredController.dispose();
    super.dispose();
  }

  Future<void> _loadNotesForSelectedDay() async {
    setState(() {
      _isLoading = true;
    });

    // 重置动画
    _listAnimationController.reset();
    _staggeredController.reset();

    try {
      List<Note> notes;
      if (_rangeStart != null && _rangeEnd != null) {
        // 如果有日期范围，加载范围内的记录
        notes = await DatabaseHelper().getNotesByDateRange(_rangeStart!, _rangeEnd!, _selectedMood);
      } else {
        // 否则加载单日记录
        if (_selectedMood == null) {
          notes = await DatabaseHelper().getNotesByDate(_selectedDay);
        } else {
          notes = await DatabaseHelper().getNotesByDateAndMood(_selectedDay, _selectedMood);
        }
      }
      
      setState(() {
        _notes = notes;
      });

      // 重新加载记录数量（修复日历显示）
      await _loadNoteCountsForMonth();

      // 启动动画
      _listAnimationController.forward();
      if (_notes.isNotEmpty) {
        _staggeredController.forward();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onDaySelected(DateTime selectedDay) {
    HapticFeedback.selectionClick(); // 触觉反馈
    setState(() {
      _selectedDay = selectedDay;
      // 清除日期范围选择
      _rangeStart = null;
      _rangeEnd = null;
    });
    _loadNotesForSelectedDay();
  }

  void _onDateRangeSelected(DateTime? start, DateTime? end) {
    HapticFeedback.selectionClick(); // 触觉反馈
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      if (start != null) {
        _selectedDay = start; // 更新选中日期为开始日期
      }
    });
    _loadNotesForSelectedDay();
  }

  void _onMoodFilterChanged(String? mood) {
    HapticFeedback.selectionClick(); // 触觉反馈
    setState(() {
      _selectedMood = mood;
    });
    _moodFilterController.forward().then((_) {
      _moodFilterController.reverse();
    });
    _loadNotesForSelectedDay();
  }

  Future<void> _showDatePicker() async {
    HapticFeedback.mediumImpact(); // 触觉反馈
    
    final Map<String, DateTime?>? result = await showModalBottomSheet<Map<String, DateTime?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCalendarModal(),
    );

    if (result != null) {
      final start = result['start'];
      final end = result['end'];
      
      if (start != null && end != null) {
        // 日期范围选择
        _onDateRangeSelected(start, end);
      } else if (start != null) {
        // 单日选择
        _onDaySelected(start);
      }
    }
  }

  Widget _buildCalendarModal() {
    DateTime? tempRangeStart = _rangeStart;
    DateTime? tempRangeEnd = _rangeEnd;
    DateTime tempSelectedDay = _selectedDay;
    
    return StatefulBuilder(
      builder: (context, setModalState) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 日历标题和选择状态
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '选择日期',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.pop(context, {
                                    'start': tempRangeStart ?? tempSelectedDay,
                                    'end': tempRangeEnd,
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF31DA9F),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 显示当前选择状态
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF31DA9F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: const Color(0xFF31DA9F),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getSelectionHint(tempRangeStart, tempRangeEnd, tempSelectedDay),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF31DA9F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 日历组件
                Container(
                  margin: const EdgeInsets.all(16),
                  child: TableCalendar<Note>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: tempSelectedDay,
                    rangeStartDay: tempRangeStart,
                    rangeEndDay: tempRangeEnd,
                    rangeSelectionMode: RangeSelectionMode.toggledOn,
                    selectedDayPredicate: (day) => 
                        tempRangeStart == null && tempRangeEnd == null && isSameDay(tempSelectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      HapticFeedback.selectionClick();
                      setModalState(() {
                        tempSelectedDay = selectedDay;
                        tempRangeStart = null;
                        tempRangeEnd = null;
                      });
                    },
                    onRangeSelected: (start, end, focusedDay) {
                      HapticFeedback.selectionClick();
                      setModalState(() {
                        tempRangeStart = start;
                        tempRangeEnd = end;
                        if (start != null) {
                          tempSelectedDay = start;
                        }
                      });
                    },
                    onPageChanged: (focusedDay) {
                      // 当月份改变时重新加载记录数量
                      if (tempSelectedDay.month != focusedDay.month || tempSelectedDay.year != focusedDay.year) {
                        setModalState(() {
                          tempSelectedDay = focusedDay;
                        });
                        // 异步更新记录数量
                        _loadNoteCountsForMonth();
                      }
                    },
                    calendarBuilders: CalendarBuilders(
                      // 自定义日期显示，添加记录数量提示
                      defaultBuilder: (context, day, focusedDay) {
                        final count = _getNoteCountForDay(day);
                        return _buildDayCell(day, count, false, false, false);
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        final count = _getNoteCountForDay(day);
                        return _buildDayCell(day, count, true, false, false);
                      },
                      todayBuilder: (context, day, focusedDay) {
                        final count = _getNoteCountForDay(day);
                        return _buildDayCell(day, count, false, true, false);
                      },
                      rangeStartBuilder: (context, day, focusedDay) {
                        final count = _getNoteCountForDay(day);
                        return _buildDayCell(day, count, false, false, true);
                      },
                      rangeEndBuilder: (context, day, focusedDay) {
                        final count = _getNoteCountForDay(day);
                        return _buildDayCell(day, count, false, false, true);
                      },
                      withinRangeBuilder: (context, day, focusedDay) {
                        final count = _getNoteCountForDay(day);
                        return _buildDayCell(day, count, false, false, false, isInRange: true);
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      // 移除默认装饰，使用自定义构建器
                      selectedDecoration: BoxDecoration(color: Colors.transparent),
                      todayDecoration: BoxDecoration(color: Colors.transparent),
                      defaultDecoration: BoxDecoration(color: Colors.transparent),
                      rangeStartDecoration: BoxDecoration(color: Colors.transparent),
                      rangeEndDecoration: BoxDecoration(color: Colors.transparent),
                      rangeHighlightColor: Colors.transparent,
                      withinRangeDecoration: BoxDecoration(color: Colors.transparent),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF31DA9F)),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF31DA9F)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getSelectionHint(DateTime? rangeStart, DateTime? rangeEnd, DateTime selectedDay) {
    if (rangeStart != null && rangeEnd != null) {
      return '已选择: ${DateFormat('MM月dd日').format(rangeStart)} - ${DateFormat('MM月dd日').format(rangeEnd)}';
    } else if (rangeStart != null) {
      return '开始日期: ${DateFormat('MM月dd日').format(rangeStart)}，请选择结束日期';
    } else {
      return '单日选择: ${DateFormat('MM月dd日').format(selectedDay)}，或点击两个日期选择范围';
    }
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          onTap: _showDatePicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: const Color(0xFF31DA9F),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getDateDisplayText(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDateDisplayText() {
    if (_rangeStart != null && _rangeEnd != null) {
      if (isSameDay(_rangeStart!, _rangeEnd!)) {
        return DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_rangeStart!);
      } else {
        return '${DateFormat('MM月dd日', 'zh_CN').format(_rangeStart!)} - ${DateFormat('MM月dd日', 'zh_CN').format(_rangeEnd!)}';
      }
    } else {
      return DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDay);
    }
  }

  Widget _buildMoodFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "全部"选项
                _buildMoodChip(null, '全部', null),
                const SizedBox(width: 8),
                // 心情选项
                ..._moodOptions.map((mood) {
                  final moodValue = '${mood['emoji']}${mood['label']}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildMoodChip(moodValue, mood['label']!, mood['emoji']!),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChip(String? moodValue, String label, String? emoji) {
    final isSelected = _selectedMood == moodValue;
    
    return AnimatedBuilder(
      animation: _moodFilterController,
      builder: (context, child) {
        return Transform.scale(
          scale: isSelected ? 1.0 + (_moodFilterController.value * 0.1) : 1.0,
          child: GestureDetector(
            onTap: () => _onMoodFilterChanged(moodValue),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF31DA9F) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? const Color(0xFF31DA9F) : Colors.grey.shade300,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: const Color(0xFF31DA9F).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (emoji != null) ...[
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesList() {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF31DA9F)),
          ),
        ),
      );
    }

    if (_notes.isEmpty) {
      return Expanded(
        child: FadeTransition(
          opacity: _listFadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyStateText(),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: SlideTransition(
        position: _listSlideAnimation,
        child: FadeTransition(
          opacity: _listFadeAnimation,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _notes.length,
            itemBuilder: (context, index) {
              return _buildStaggeredNoteCard(_notes[index], index);
            },
          ),
        ),
      ),
    );
  }

  String _getEmptyStateText() {
    if (_rangeStart != null && _rangeEnd != null) {
      if (_selectedMood == null) {
        return '这个日期范围内还没有记录';
      } else {
        return '这个日期范围内没有${_selectedMood!.substring(2)}的记录';
      }
    } else {
      if (_selectedMood == null) {
        return '这一天还没有记录';
      } else {
        return '这一天没有${_selectedMood!.substring(2)}的记录';
      }
    }
  }

  Widget _buildStaggeredNoteCard(Note note, int index) {
    final animationInterval = Interval(
      (index * 0.1).clamp(0.0, 1.0),
      ((index * 0.1) + 0.3).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: _staggeredController,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _staggeredController,
          curve: animationInterval,
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _staggeredController,
          curve: animationInterval,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: _buildNoteCard(note),
          ),
        );
      },
    );
  }

  Widget _buildNoteCard(Note note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => HapticFeedback.lightImpact(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 显示心情图标
                    if (note.mood != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          // color: const Color(0xFF31DA9F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note.mood!.substring(0, 2),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.content,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('MM月dd日').format(note.createdAt)} ${DateFormat('HH:mm').format(note.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('编辑'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        HapticFeedback.selectionClick();
                        if (value == 'edit') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddNotePage(note: note),
                            ),
                          );
                          if (result == true) {
                            _loadNotesForSelectedDay(); // 这里会同时更新记录数量
                          }
                        } else if (value == 'delete') {
                          _deleteNote(note);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, true);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper().deleteNote(note.id!);
      _loadNotesForSelectedDay(); // 这里会同时更新记录数量
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F8F2),
      appBar: AppBar(
        title: const Text('Voca'),
        backgroundColor: const Color(0xFF31DA9F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsPage()),
              );
            },
            tooltip: '数据统计',
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatPage()),
              );
            },
            tooltip: 'AI助手',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'deepseek_settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DeepSeekSettingsPage()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'deepseek_settings',
                child: Row(
                  children: [
                    Icon(Icons.smart_toy),
                    SizedBox(width: 8),
                    Text('AI设置'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
          // 仅在调试模式下显示
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DebugPage()),
                );
              },
              tooltip: '调试工具',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildMoodFilter(),
          const SizedBox(height: 16),
          _buildNotesList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddNotePage()),
          );
          if (result == true) {
            _loadNotesForSelectedDay(); // 这里会同时更新记录数量
          }
        },
        backgroundColor: const Color(0xFF31DA9F),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // 构建自定义日期单元格
  Widget _buildDayCell(DateTime day, int count, bool isSelected, bool isToday, bool isRangeEnd, {bool isInRange = false}) {
    Color backgroundColor;
    Color textColor;
    
    if (isSelected || isRangeEnd) {
      backgroundColor = const Color(0xFF31DA9F);
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = const Color(0xFF7AE6B8);
      textColor = Colors.white;
    } else if (isInRange) {
      backgroundColor = const Color(0xFFE8F8F2);
      textColor = Colors.black87;
    } else {
      backgroundColor = Colors.transparent;
      textColor = Colors.black87;
    }
    
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // 日期数字
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected || isToday || isRangeEnd ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          // 记录数量提示
          if (count > 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected || isToday || isRangeEnd
                      ? Colors.white
                      : const Color(0xFF31DA9F),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: TextStyle(
                      color: isSelected || isToday || isRangeEnd
                          ? const Color(0xFF31DA9F)
                          : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
