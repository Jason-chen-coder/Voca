import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../services/chat_database_service.dart';
import '../services/ai_chat_service.dart';
import '../../services/deepseek_config_service.dart';
import '../../pages/deepseek_settings_page.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatDatabaseService _chatDb = ChatDatabaseService();
  final AIChatService _aiService = AIChatService();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  bool _isAIResponding = false; // 新增：AI正在回复的状态
  late AnimationController _animationController;
  bool _showQuickQuestions = false;
  late AnimationController _quickQuestionsController;
  late Animation<double> _quickQuestionsAnimation;
  bool _isInputFocused = false;
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // 快速问题动画控制器
    _quickQuestionsController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _quickQuestionsAnimation = CurvedAnimation(
      parent: _quickQuestionsController,
      curve: Curves.easeInOut,
    );
    
    // 监听输入框焦点变化
    _messageController.addListener(_onInputChanged);
    
    _loadChatHistory();
    _checkApiConfiguration();
  }

  Future<void> _checkApiConfiguration() async {
    final hasKey = await DeepSeekConfigService.hasApiKey();
    setState(() {
      _hasApiKey = hasKey;
    });
    
    // 如果没有配置API密钥，显示提示
    if (!hasKey && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showApiConfigDialog();
      });
    }
  }

  void _showApiConfigDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFF8BC34A)),
            SizedBox(width: 8),
            Text('配置AI功能'),
          ],
        ),
        content: const Text(
          '要使用AI智能分析功能，需要先配置DeepSeek API密钥。\n\n'
          '您可以稍后在设置中配置，或者现在就去配置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后配置'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8BC34A),
              foregroundColor: Colors.white,
            ),
            child: const Text('立即配置'),
          ),
        ],
      ),
    );
  }

  void _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeepSeekSettingsPage()),
    );
    
    // 返回后重新检查配置
    _checkApiConfiguration();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _quickQuestionsController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    // 移除自动显示快速问题的逻辑
    // 现在只通过手动点击按钮来控制
  }

  void _toggleQuickQuestions() {
    setState(() {
      _showQuickQuestions = !_showQuickQuestions;
    });
    if (_showQuickQuestions) {
      _quickQuestionsController.forward();
    } else {
      _quickQuestionsController.reverse();
    }
  }

  void _selectQuickQuestion(String question) {
    _messageController.text = question;
    setState(() {
      _showQuickQuestions = false;
    });
    _quickQuestionsController.reverse();
    // 直接发送消息，让大模型处理
    _sendMessage(question);
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _chatDb.getRecentMessages();
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar('加载聊天记录失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty || _isAIResponding) return; // 如果AI正在回复则不能发送

    final userMessage = ChatMessage(
      content: content,
      isUser: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isAIResponding = true; // 设置AI正在回复状态
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // 保存用户消息
      await _chatDb.insertMessage(userMessage);

      // 创建AI消息占位符
      final aiMessage = ChatMessage(
        content: '',
        isUser: false,
        createdAt: DateTime.now(),
      );
      
      setState(() {
        _messages.add(aiMessage);
      });

      // 流式获取AI回复
      await for (final partialResponse in _aiService.processMessageStream(content)) {
        setState(() {
          _messages[_messages.length - 1] = ChatMessage(
            content: partialResponse,
            isUser: false,
            createdAt: aiMessage.createdAt,
          );
        });
        _scrollToBottom();
      }

      // 保存完整的AI回复
      await _chatDb.insertMessage(_messages.last);

    } catch (e) {
      _showErrorSnackBar('发送消息失败: $e');
    } finally {
      setState(() {
        _isAIResponding = false; // 重置AI回复状态
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    print("_showErrorSnackBar===>message===>${message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _chatDb.clearAllMessages();
        setState(() => _messages.clear());
      } catch (e) {
        _showErrorSnackBar('清空失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('AI 智能助手'),
        backgroundColor: const Color(0xFF8BC34A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // API状态指示器
          IconButton(
            icon: Icon(
              _hasApiKey ? Icons.cloud_done : Icons.cloud_off,
              color: _hasApiKey ? Colors.white : Colors.white70,
            ),
            onPressed: _navigateToSettings,
            tooltip: _hasApiKey ? 'API已配置' : '配置API',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChat,
            tooltip: '清空聊天',
          ),
        ],
      ),
      body: Column(
        children: [
          // API未配置时显示提示条
          if (!_hasApiKey) _buildApiWarningBanner(),
          // 只在消息为空时显示顶部预设问题
          if (_messages.isEmpty) _buildPresetQuestions(),
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildApiWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange[100],
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI功能需要配置API密钥',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: _navigateToSettings,
            child: Text(
              '立即配置',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetQuestions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 20,
                color: Color(0xFF8BC34A),
              ),
              const SizedBox(width: 8),
              const Text(
                '开始对话',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '选择一个话题开始，或直接输入您的问题',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickQuestionsGrid(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8BC34A)),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF8BC34A),
              child: const Icon(Icons.smart_toy, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF8BC34A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 如果是AI消息且内容为空且正在回复，显示loading
                  if (!message.isUser && message.content.isEmpty && _isAIResponding)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI正在思考中...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  // 如果是AI消息且有内容但仍在回复，显示内容
                  else if (!message.isUser && message.content.isNotEmpty && _isAIResponding)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[500]!),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '正在输入...',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFA5D6A7),
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF8BC34A),
            child: const Icon(Icons.smart_toy, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = (_animationController.value + index * 0.3) % 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color.lerp(Colors.grey[400], const Color(0xFF8BC34A), value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快速问题展开区域
          AnimatedBuilder(
            animation: _quickQuestionsAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _quickQuestionsAnimation,
                child: _buildQuickQuestionsPanel(),
              );
            },
          ),
          
          // 输入区域
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 快速问题按钮
                IconButton(
                  onPressed: _isAIResponding ? null : _toggleQuickQuestions, // AI回复时禁用
                  icon: AnimatedRotation(
                    turns: _showQuickQuestions ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.lightbulb_outline),
                  ),
                  color: _isAIResponding 
                      ? Colors.grey[400]
                      : (_showQuickQuestions 
                          ? const Color(0xFF8BC34A) 
                          : Colors.grey[600]),
                  tooltip: '快速问题',
                ),
                
                const SizedBox(width: 8),
                
                // 输入框
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isAIResponding, // AI回复时禁用输入
                    decoration: InputDecoration(
                      hintText: _isAIResponding ? 'AI正在回复中...' : '输入您的问题...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _isAIResponding 
                          ? Colors.grey[100] 
                          : const Color(0xFFF1F8E9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _isAIResponding ? null : _sendMessage,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                      return currentLength > 400 
                          ? Text(
                              '$currentLength/$maxLength',
                              style: TextStyle(
                                color: currentLength > 450 ? Colors.red : Colors.grey,
                                fontSize: 12,
                              ),
                            )
                          : null;
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 发送按钮
                FloatingActionButton(
                  onPressed: (_messageController.text.trim().isNotEmpty && !_isAIResponding)
                      ? () => _sendMessage(_messageController.text)
                      : null,
                  backgroundColor: (_messageController.text.trim().isNotEmpty && !_isAIResponding)
                      ? const Color(0xFF8BC34A)
                      : Colors.grey[300],
                  mini: true,
                  child: _isAIResponding
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: (_messageController.text.trim().isNotEmpty && !_isAIResponding)
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestionsPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Color(0xFF8BC34A),
              ),
              const SizedBox(width: 8),
              const Text(
                '快速问题',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _toggleQuickQuestions,
                child: const Text(
                  '收起',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8BC34A),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 快速问题网格
          _buildQuickQuestionsGrid(),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickQuestionsGrid() {
    final questions = _aiService.getPresetQuestions();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: questions.map((question) {
        return _buildQuickQuestionChip(question);
      }).toList(),
    );
  }

  Widget _buildQuickQuestionChip(String question) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectQuickQuestion(question),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8BC34A).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getQuestionIcon(question),
                size: 16,
                color: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getQuestionIcon(String question) {
    if (question.contains('记录情况') || question.contains('分析')) {
      return Icons.analytics;
    } else if (question.contains('心情') || question.contains('情绪')) {
      return Icons.mood;
    } else if (question.contains('内容')) {
      return Icons.article;
    } else if (question.contains('行为') || question.contains('习惯')) {
      return Icons.insights;
    } else if (question.contains('建议')) {
      return Icons.tips_and_updates;
    }
    return Icons.help_outline;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      // 今天只显示时间
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // 昨天显示"昨天 HH:mm"
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      // 其他日期显示"MM-dd HH:mm"
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
  }
}
