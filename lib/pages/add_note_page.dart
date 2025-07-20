import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/note.dart';
import '../database/database_helper.dart';

class AddNotePage extends StatefulWidget {
  final Note? note;

  const AddNotePage({super.key, this.note});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> with TickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode(); // 添加 FocusNode
  String? _selectedMood;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // 动画控制器
  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonScaleAnimation;

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

  // 鼓励性文案列表
  final List<String> _encouragementMessages = [
    "太棒了！又完成了一次记录 ✨",
    "坚持记录，见证成长的力量 🌱",
    "每一次记录都是珍贵的回忆 💎",
    "记录让生活更有意义 🌟",
    "你的坚持值得赞赏 👏",
    "又一个美好的瞬间被记录下来 📝",
    "记录是最好的自我陪伴 💝",
    "每一笔都是对生活的热爱 ❤️",
    "记录让时光变得更加珍贵 ⏰",
    "你的文字充满了力量 💪",
    "记录是心灵的对话 💭",
    "坚持记录，收获满满 🎁",
    "文字见证你的每一天 📖",
    "记录让回忆更加清晰 🔍",
    "你的坚持让人感动 🥰",
    "每一次记录都是成长的足迹 👣",
    "文字是最好的时光机器 🕰️",
    "记录让生活充满仪式感 🎭",
    "你的每一个想法都值得被记录 💡",
    "坚持记录，遇见更好的自己 🌈",
    "记录是对生活最好的礼物 🎀",
    "文字让情感有了归宿 🏠",
    "每一次记录都是对未来的投资 💰",
    "记录让平凡的日子闪闪发光 ✨",
    "你的文字温暖了时光 🔥",
    "记录是心灵的港湾 ⚓",
    "坚持记录，生活更精彩 🎨",
    "每一个字都承载着美好 🌸",
    "记录让思绪有了方向 🧭",
    "你的坚持创造了奇迹 🎪"
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.note != null) {
      _contentController.text = widget.note!.content;
      _selectedMood = widget.note!.mood;
      _selectedDate = widget.note!.createdAt;
    } else {
      // 新建记录时自动聚焦到输入框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contentFocusNode.requestFocus();
      });
    }
  }

  void _initAnimations() {
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _saveButtonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _saveButtonController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose(); // 释放 FocusNode
    _contentFocusNode.dispose(); // 释放 FocusNode
    _saveButtonController.dispose();
    super.dispose();
  }

  void _selectMood(String mood) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMood = _selectedMood == mood ? null : mood;
    });
  }

  Future<void> _selectDate() async {
    HapticFeedback.mediumImpact();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8BC34A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_contentController.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入记录内容'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedMood == null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择一个心情'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _saveButtonController.forward().then((_) {
      _saveButtonController.reverse();
    });

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final note = Note(
      id: widget.note?.id,
      content: _contentController.text.trim(),
      createdAt: widget.note?.createdAt ?? DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      ),
      updatedAt: now,
      mood: _selectedMood,
    );

    try {
      if (widget.note == null) {
        await DatabaseHelper().insertNote(note);
      } else {
        await DatabaseHelper().updateNote(note);
      }
      
      if (mounted) {
        _showSuccessMessage();
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, true);
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: _saveNote,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessMessage() {
    HapticFeedback.heavyImpact();
    final random = Random();
    final message = _encouragementMessages[random.nextInt(_encouragementMessages.length)];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8BC34A),
        duration: const Duration(milliseconds: 2500),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(widget.note == null ? '新建记录' : '编辑记录'),
        backgroundColor: const Color(0xFF8BC34A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0,left: 16,right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期选择器
                  _DateSelector(
                    selectedDate: _selectedDate,
                    onDateTap: _selectDate,
                  ),
                  const SizedBox(height: 20),
                  
                  // 内容输入框
                  _ContentInput(
                    controller: _contentController,
                    focusNode: _contentFocusNode, // 传递 FocusNode
                  ),
                  const SizedBox(height: 20),
                  
                  // 心情选择区域
                  _MoodSelector(
                    moodOptions: _moodOptions,
                    selectedMood: _selectedMood,
                    onMoodSelect: _selectMood,
                  ),
                  const SizedBox(height: 20),
                  // 底部保存按钮
                  _SaveButton(
                    isLoading: _isLoading,
                    isEdit: widget.note != null,
                    animation: _saveButtonScaleAnimation,
                    onSave: _saveNote,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 日期选择器组件
class _DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onDateTap;

  const _DateSelector({
    required this.selectedDate,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onDateTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: const Color(0xFF8BC34A),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_right,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 内容输入框组件
class _ContentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _ContentInput({
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        focusNode: focusNode, // 使用传入的 FocusNode
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          hintText: '记录你的想法...',
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF8BC34A), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}

// 心情选择器组件
class _MoodSelector extends StatelessWidget {
  final List<Map<String, String>> moodOptions;
  final String? selectedMood;
  final Function(String) onMoodSelect;

  const _MoodSelector({
    required this.moodOptions,
    required this.selectedMood,
    required this.onMoodSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '心情',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moodOptions.map((mood) {
            final moodValue = '${mood['emoji']}${mood['label']}';
            final isSelected = selectedMood == moodValue;
            return GestureDetector(
              onTap: () => onMoodSelect(moodValue),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8BC34A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF8BC34A) : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFF8BC34A).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mood['emoji']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mood['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// 保存按钮组件
class _SaveButton extends StatelessWidget {
  final bool isLoading;
  final bool isEdit;
  final Animation<double> animation;
  final VoidCallback onSave;

  const _SaveButton({
    required this.isLoading,
    required this.isEdit,
    required this.animation,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: animation.value,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8BC34A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: isLoading ? 0 : 4,
                    shadowColor: const Color(0xFF8BC34A).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '保存中...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isEdit ? '更新' : '保存',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
