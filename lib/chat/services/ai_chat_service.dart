import 'dart:async';

import 'package:dart_openai/dart_openai.dart';
import '../../services/models/ai_insights.dart';
import '../models/chat_message.dart';
import '../../services/analytics_service.dart';
import '../../services/models/analytics_models.dart';
import '../../services/deepseek_config_service.dart';
import '../../services/ai_agent_service.dart';
import 'chat_database_service.dart';
import 'dart:convert';
import 'dart:math' as math;

class AIChatService {
  final AnalyticsService _analyticsService = AnalyticsService();
  final AIAgentService _aiAgent = AIAgentService();
  StreamSubscription? _lastStreamSub;

  // 系统提示词
  static const String _systemPrompt = '''
你是Voca AI助手，一个专业的智能速记分析助手。

**产品背景：**
Voca是一款支持语音、手写和文字输入的智能速记工具，帮助用户轻松记录灵感、会议和生活点滴，并提供AI自动整理总结功能。

**你的角色：**
- 帮助用户分析他们的记录数据和使用习惯
- 提供个性化的记录建议和情绪洞察
- 回答关于应用使用的问题
- 基于用户的记录数据生成有价值的分析报告

**回复风格：**
- 友好、专业、简洁
- 使用中文回复，符合中文用户习惯
- 提供具体可行的建议
- 适当使用emoji增加亲和力

**可用功能：**
当用户询问数据分析相关问题时，你可以调用以下函数获取真实数据：
- getUserRecordStats: 获取用户记录统计
- getMoodTrendAnalysis: 分析心情变化趋势  
- getUsageBehaviorAnalysis: 分析使用行为模式
- getContentAnalysisInsights: 分析记录内容特征
- generateUserInsightReport: 生成综合洞察报告
- getQuickInsightSummary: 获取快速洞察摘要

请根据用户的具体问题，智能选择合适的分析功能，并以易懂的方式解释分析结果。
''';

  /// 清理文本中的无效UTF-16字符和JSON特殊字符
  String _sanitizeText(String text) {
    if (text.isEmpty) return text;

    // 移除无效的UTF-16字符和JSON问题字符
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final codeUnit = char.codeUnitAt(0);

      // 跳过无效的UTF-16代理对和控制字符
      if (codeUnit >= 0xD800 && codeUnit <= 0xDFFF) {
        // 处理代理对
        if (i + 1 < text.length) {
          final nextCodeUnit = text.codeUnitAt(i + 1);
          if (codeUnit >= 0xD800 &&
              codeUnit <= 0xDBFF &&
              nextCodeUnit >= 0xDC00 &&
              nextCodeUnit <= 0xDFFF) {
            // 有效的代理对
            buffer.write(char);
            buffer.write(text[i + 1]);
            i++; // 跳过下一个字符
          }
          // 无效的代理对，跳过
        }
      } else if (codeUnit == 0xFEFF || // BOM
          (codeUnit >= 0x0000 &&
              codeUnit <= 0x001F &&
              codeUnit != 0x0009 &&
              codeUnit != 0x000A &&
              codeUnit != 0x000D) ||
          (codeUnit >= 0x007F && codeUnit <= 0x009F) ||
          codeUnit == 0xFFFE ||
          codeUnit == 0xFFFF) {
        // 添加更多无效字符
        // 跳过BOM和控制字符（保留制表符、换行符、回车符）
        continue;
      } else {
        buffer.write(char);
      }
    }

    // 进一步清理可能导致JSON问题的字符
    String result = buffer.toString();

    // 移除或替换可能导致JSON解析问题的字符
    result = result.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'),
      '',
    );

    // 确保字符串不包含未转义的引号和反斜杠
    result = result.replaceAll(r'\', r'\\');
    result = result.replaceAll('"', r'\"');

    return result.trim();
  }

  /// 构建可用工具列表
  List<OpenAIToolModel> _buildAvailableTools() {
    return [
      OpenAIToolModel(
        type: 'function',
        function: OpenAIFunctionModel(
          name: 'getUserRecordStats',
          description: '获取用户记录统计数据，包括总记录数、日均记录、活跃天数等',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'period': {
                'type': 'string',
                'enum': ['thisWeek', 'thisMonth', 'all'],
                'description': '统计时间范围',
              },
            },
            'required': ['period'],
          },
        ),
      ),
      OpenAIToolModel(
        type: 'function',
        function: OpenAIFunctionModel(
          name: 'getMoodTrendAnalysis',
          description: '分析用户心情变化趋势和情绪状态',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'period': {
                'type': 'string',
                'enum': ['thisWeek', 'thisMonth', 'all'],
                'description': '分析时间范围',
              },
            },
            'required': ['period'],
          },
        ),
      ),
      OpenAIToolModel(
        type: 'function',
        function: OpenAIFunctionModel(
          name: 'getUsageBehaviorAnalysis',
          description: '分析用户使用行为模式和习惯',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'period': {
                'type': 'string',
                'enum': ['thisWeek', 'thisMonth', 'all'],
                'description': '分析时间范围',
              },
            },
            'required': ['period'],
          },
        ),
      ),
      OpenAIToolModel(
        type: 'function',
        function: OpenAIFunctionModel(
          name: 'getContentAnalysisInsights',
          description: '分析记录内容特征和质量',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'period': {
                'type': 'string',
                'enum': ['thisWeek', 'thisMonth', 'all'],
                'description': '分析时间范围',
              },
            },
            'required': ['period'],
          },
        ),
      ),
      OpenAIToolModel(
        type: 'function',
        function: OpenAIFunctionModel(
          name: 'generateUserInsightReport',
          description: '生成综合的用户洞察分析报告',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'period': {
                'type': 'string',
                'enum': ['thisWeek', 'thisMonth', 'all'],
                'description': '报告时间范围',
              },
            },
            'required': ['period'],
          },
        ),
      ),
      OpenAIToolModel(
        type: 'function',
        function: OpenAIFunctionModel(
          name: 'getQuickInsightSummary',
          description: '获取快速洞察摘要',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'period': {
                'type': 'string',
                'enum': ['thisWeek', 'thisMonth', 'all'],
                'description': '摘要时间范围',
              },
            },
            'required': ['period'],
          },
        ),
      ),
    ];
  }


  Stream<String> processMessageStream(String userMessage) async* {
    // Cancel any previous stream
    await _lastStreamSub?.cancel();
    _lastStreamSub = null;

    try {
      print('开始处理消息: "$userMessage"');
      final hasApiKey = await DeepSeekConfigService.hasApiKey();
      if (!hasApiKey) {
        yield '请先在设置中配置DeepSeek API密钥才能使用AI功能。';
        return;
      }

      final chatDb = ChatDatabaseService();
      final historyMessages = await chatDb.getRecentMessages(limit: 10);
      final dialog = <ChatMessage>[];
      OpenAIChatMessageRole? last;

      for (int i = historyMessages.length - 1; i >= 0; i--) {
        final m = historyMessages[i];
        final role = m.isUser ? OpenAIChatMessageRole.user : OpenAIChatMessageRole.assistant;
        if (role == last) continue;
        dialog.insert(0, m);
        last = role;
        if (dialog.length >= 10) break;
      }

      final messages = <OpenAIChatCompletionChoiceMessageModel>[
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(_systemPrompt)],
        ),
      ];

      // 添加历史对话
      for (final msg in dialog) {
        final role = msg.isUser ? OpenAIChatMessageRole.user : OpenAIChatMessageRole.assistant;
        messages.add(OpenAIChatCompletionChoiceMessageModel(
          role: role,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(_sanitizeText(msg.content))],
        ));
      }

      final cleanUser = _sanitizeText(userMessage.trim());
      messages.add(OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(cleanUser)],
      ));

      yield* _processWithToolCalls(messages);
    } catch (e, st) {
      print('❌ 全局异常: $e\n$st');
      yield '抱歉，AI服务暂时不可用，请稍后重试。';
    }
  }

  Stream<String> _processWithToolCalls(List<OpenAIChatCompletionChoiceMessageModel> messages) async* {
    final stream = DeepSeekConfigService.createChatCompletionStream(
      model: 'deepseek-chat',
      messages: messages,
      tools: _buildAvailableTools(),
      toolChoice: 'auto',
    );

    if (stream == null) {
      print('⚠️ Stream is null');
      yield '抱歉，无法连接 AI 服务，请稍后重试。';
      return;
    }

    print('✅ Stream 创建成功，开始监听...');
    String accumulated = '';
    Map<int, Map<String, String>> pendingToolCalls = {};
    final controller = StreamController<String>();

    _lastStreamSub = stream.listen(
      (event) async {
        print("event===>${event}");
        final choice = event.choices.isNotEmpty ? event.choices.first : null;
        
        // 处理工具调用
        if (choice?.delta.toolCalls != null && choice!.delta.toolCalls!.isNotEmpty) {
          for (final toolCall in choice.delta.toolCalls!) {
            if ((toolCall as OpenAIStreamResponseToolCall).index != null) {
              final index = toolCall.index!;
              if (!pendingToolCalls.containsKey(index)) {
                pendingToolCalls[index] = {
                  'id': '',
                  'name': '',
                  'arguments': '',
                };
              }
              
              final existing = pendingToolCalls[index]!;
              pendingToolCalls[index] = {
                'id': toolCall.id ?? existing['id']!,
                'name': toolCall.function?.name ?? existing['name']!,
                'arguments': existing['arguments']! + (toolCall.function?.arguments ?? ''),
              };
            }
          }
        }
        
        // 处理文本内容
        final contents = choice?.delta.content;
        if (contents != null) {
          for (final c in contents) {
            final t = _sanitizeText(c?.text ?? '');
            if (t.isNotEmpty) {
              accumulated += t;
              if (!controller.isClosed) {
                controller.add(accumulated);
              }
            }
          }
        }
        
        // 如果流结束且有工具调用，执行工具调用并重新请求AI
        if (choice?.finishReason == 'tool_calls' && pendingToolCalls.isNotEmpty) {
          if (!controller.isClosed) {
            controller.add(accumulated + '\n\n🔍 正在分析数据...\n\n');
          }

          // 执行工具调用并添加结果消息
          for (final toolCall in pendingToolCalls.values) {
            final name = toolCall['name']!;
            final arguments = toolCall['arguments']!;
            final toolCallId = toolCall['id']!;
            
            if (name.isNotEmpty) {
              try {
                final result = await _handleToolCall(name, arguments);
                print('工具调用结果name:${name};result: $result');

              } catch (e) {
                print('工具调用失败: $e');

              }
            }
          }
          
          // 关闭当前控制器
          if (!controller.isClosed) {
            controller.close();
          }
          
          // 重新调用AI处理工具调用结果
          _processWithToolCalls(messages).listen(
            (data) {
              if (!controller.isClosed) {
                controller.add(data);
              }
            },
            onError: (e) {
              if (!controller.isClosed) {
                controller.add('处理工具调用结果时出错，请稍后重试。');
                controller.close();
              }
            },
            onDone: () {
              if (!controller.isClosed) {
                controller.close();
              }
            },
          );
          return;
        }
      },
      onError: (e, st) {
        print('❌ Stream error: $e\n$st');
        if (!controller.isClosed) {
          controller.add('抱歉，AI服务暂时不可用，请稍后重试。');
          controller.close();
        }
      },
      onDone: () {
        print('🎉 Stream 完成');
        if (!controller.isClosed) {
          controller.close();
        }
      },
      cancelOnError: true,
    );

    yield* controller.stream;
  }
  /// 处理工具调用
  Future<String> _handleToolCall(String toolName, String arguments) async {
    try {
      // 检查参数是否为空或无效
      if (arguments.isEmpty || arguments.trim().isEmpty) {
        print('工具调用参数为空，使用默认参数');
        arguments = '{"period": "thisMonth"}'; // 提供默认参数
      }

      Map<String, dynamic> args;
      try {
        args = json.decode(arguments);
      } catch (e, stack) {
        print('JSON解析失败，参数内容: "$arguments"，错误: $e,stack:${stack}');
        // 如果JSON解析失败，使用默认参数
        args = {'period': 'thisMonth'};
      }

      final period = args['period'] ?? 'thisMonth';
      final dateRange = _getDateRange(period);

      switch (toolName) {
        case 'getUserRecordStats':
          final stats = await _analyticsService.getUserRecordStats(dateRange);
          return '用户记录统计：总记录数${stats.totalRecords}条，日均${stats.averageDaily.toStringAsFixed(1)}条，活跃天数${stats.activeDays}/${stats.totalDays}天，心情种类${stats.moodVariety}种';

        case 'getMoodTrendAnalysis':
          final analysis = await _analyticsService.getMoodTrendAnalysis(dateRange);
          return '心情趋势分析：平均心情指数${analysis.averageMoodIndex.toStringAsFixed(1)}，心情水平${analysis.moodLevel}，情绪波动性${analysis.moodVolatility.toStringAsFixed(2)}';

        case 'getUsageBehaviorAnalysis':
          final behavior = await _analyticsService.getUsageBehaviorAnalysis(dateRange);
          return '使用行为分析：最活跃时段${behavior.mostActiveHour}点，平均使用时长${behavior}分钟，使用频率${behavior}';

        case 'getContentAnalysisInsights':
          final insights = await _analyticsService.getContentAnalysisInsights(dateRange);
          return '内容分析洞察：平均内容长度${insights.averageContentLength.toStringAsFixed(0)}字，内容质量${insights}，主要话题${insights}';

        case 'generateUserInsightReport':
          final report = await _aiAgent.generateUserInsightReport(dateRange);
          return '用户洞察报告：记录统计-总数${report.recordStats.totalRecords}条，日均${report.recordStats.averageDaily.toStringAsFixed(1)}条；心情分析-平均指数${report.moodTrend.averageMoodIndex.toStringAsFixed(1)}，水平${report.moodTrend.moodLevel}';

        case 'getQuickInsightSummary':
          final summary = await _aiAgent.getQuickInsightSummary(dateRange);
          return '快速洞察摘要：总记录${summary.totalRecords}条，心情状态${summary.moodLevel}，活跃程度${summary.activityLevel}，主要心情${summary.dominantMood}';

        default:
          return '抱歉，暂不支持该分析功能。';
      }
    } catch (e, stack) {
      print('分析数据时出现错误：$e，堆栈：$stack');
      return '分析数据时出现错误，请稍后重试。';
    }
  }


  /// 获取预设问题列表
  List<String> getPresetQuestions() {
    return [
      '分析我的记录情况',
      '我的心情变化趋势如何？',
      '帮我分析记录内容',
      '我的使用行为有什么特点？',
      '最近的情绪状态怎么样？',
      '给我一些记录建议',
    ];
  }

  DateRange _getDateRange(String period) {
    switch (period) {
      case 'thisWeek':
        return DateRange.thisWeek();
      case 'thisMonth':
        return DateRange.thisMonth();
      default:
        return DateRange.all();
    }
  }
}
