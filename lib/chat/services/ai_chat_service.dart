import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import '../../services/models/ai_insights.dart';
import '../models/chat_message.dart';
import '../../services/analytics_service.dart';
import '../../services/models/analytics_models.dart';
import '../../services/deepseek_config_service.dart';
import '../../services/ai_agent_service.dart';
import 'chat_database_service.dart';

class AIChatService {
  final AnalyticsService _analyticsService = AnalyticsService();
  final AIAgentService _aiAgent = AIAgentService();
  final Dio _dio = Dio();
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

  /// 构建请求消息格式
  List<Map<String, dynamic>> _buildMessages(
    List<ChatMessage> dialog,
    String userMessage,
  ) {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
    ];

    // 添加历史对话
    for (final msg in dialog) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': _sanitizeText(msg.content),
      });
    }

    // 添加当前用户消息
    messages.add({
      'role': 'user',
      'content': _sanitizeText(userMessage.trim()),
    });

    return messages;
  }

  /// 构建工具定义
  List<Map<String, dynamic>> _buildToolsForRequest() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'getUserRecordStats',
          'description': '获取用户记录统计数据，包括总记录数、日均记录、活跃天数等',
          'parameters': {
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
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'getMoodTrendAnalysis',
          'description': '分析用户心情变化趋势和情绪状态',
          'parameters': {
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
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'getUsageBehaviorAnalysis',
          'description': '分析用户使用行为模式和习惯',
          'parameters': {
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
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'getContentAnalysisInsights',
          'description': '分析记录内容特征和质量',
          'parameters': {
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
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'generateUserInsightReport',
          'description': '生成综合的用户洞察分析报告',
          'parameters': {
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
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'getQuickInsightSummary',
          'description': '获取快速洞察摘要',
          'parameters': {
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
        },
      },
    ];
  }

  Stream<String> processMessageStream(String userMessage) async* {
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
      final historyMessages = await chatDb.getRecentMessages(
        limit: 8,
      ); // 减少历史消息数量
      final dialog = <ChatMessage>[];

      // 简化历史消息处理，避免重复
      for (final m in historyMessages.reversed) {
        dialog.add(m);
        if (dialog.length >= 8) break;
      }

      final messages = _buildMessages(dialog, userMessage);
      yield* _processWithDioStream(messages);
    } catch (e, st) {
      print('❌ 全局异常: $e\n$st');
      yield '抱歉，AI服务暂时不可用，请稍后重试。';
    }
  }

  Stream<String> _processWithDioStream(
    List<Map<String, dynamic>> messages,
  ) async* {
    try {
      final apiKey = await DeepSeekConfigService.getApiKey();
      if (apiKey == null) {
        yield '请先配置API密钥';
        return;
      }

      final requestData = {
        'model': 'deepseek-chat',
        'messages': messages,
        'stream': true,
        'tools': _buildToolsForRequest(),
        'tool_choice': 'auto',
      };

      final response = await _dio.post(
        'https://api.deepseek.com/chat/completions',
        data: requestData,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      final controller = StreamController<String>();
      String accumulated = '';
      Map<int, Map<String, String>> pendingToolCalls = {};
      bool hasToolCalls = false;

      _lastStreamSub = (response.data as ResponseBody).stream
          .map((bytes) => utf8.decode(bytes))
          .transform(const LineSplitter())
          .listen(
            (line) async {
              if (line.isEmpty || !line.startsWith('data: ')) return;

              final data = line.substring(6);
              if (data == '[DONE]') {
                if (hasToolCalls && pendingToolCalls.isNotEmpty) {
                  await _handleToolCallsAndContinue(
                    messages,
                    pendingToolCalls,
                    controller,
                    accumulated,
                  );
                } else {
                  controller.close();
                }
                return;
              }

              try {
                final json = jsonDecode(data);
                final choices = json['choices'] as List?;
                if (choices == null || choices.isEmpty) return;

                final choice = choices.first;
                final delta = choice['delta'];

                // 处理工具调用
                if (delta['tool_calls'] != null) {
                  hasToolCalls = true;
                  final toolCalls = delta['tool_calls'] as List;
                  for (final toolCall in toolCalls) {
                    final index = toolCall['index'] as int;
                    if (!pendingToolCalls.containsKey(index)) {
                      pendingToolCalls[index] = {
                        'id': '',
                        'name': '',
                        'arguments': '',
                      };
                    }

                    final existing = pendingToolCalls[index]!;
                    pendingToolCalls[index] = {
                      'id': toolCall['id'] ?? existing['id']!,
                      'name':
                          toolCall['function']?['name'] ?? existing['name']!,
                      'arguments':
                          existing['arguments']! +
                          (toolCall['function']?['arguments'] ?? ''),
                    };
                  }
                }

                // 处理文本内容
                if (delta['content'] != null) {
                  final content = _sanitizeText(delta['content'] as String);
                  if (content.isNotEmpty) {
                    accumulated += content;
                    if (!controller.isClosed) {
                      controller.add(accumulated);
                    }
                  }
                }
              } catch (e) {
                print('解析SSE数据失败: $e');
              }
            },
            onError: (e) {
              print('❌ Stream error: $e');
              if (!controller.isClosed) {
                controller.add('抱歉，AI服务暂时不可用，请稍后重试。');
                controller.close();
              }
            },
            onDone: () {
              if (!controller.isClosed) {
                controller.close();
              }
            },
          );

      yield* controller.stream;
    } catch (e, st) {
      print('❌ Dio请求失败: $e\n$st');
      yield '抱歉，无法连接AI服务，请稍后重试。';
    }
  }

  Future<void> _handleToolCallsAndContinue(
    List<Map<String, dynamic>> messages,
    Map<int, Map<String, String>> pendingToolCalls,
    StreamController<String> controller,
    String accumulated,
  ) async {
    if (!controller.isClosed) {
      controller.add(accumulated + '\n\n🔍 正在分析数据...\n\n');
    }

    // 首先添加assistant消息（包含工具调用）
    final toolCallsForMessage =
        pendingToolCalls.values
            .map(
              (toolCall) => {
                'id': toolCall['id'],
                'type': 'function',
                'function': {
                  'name': toolCall['name'],
                  'arguments': toolCall['arguments'],
                },
              },
            )
            .toList();

    messages.add({
      'role': 'assistant',
      'content': accumulated.isNotEmpty ? accumulated : null,
      'tool_calls': toolCallsForMessage,
    });

    // 执行工具调用并添加结果
    for (final toolCall in pendingToolCalls.values) {
      final name = toolCall['name']!;
      final arguments = toolCall['arguments']!;
      final toolCallId = toolCall['id']!;

      if (name.isNotEmpty && toolCallId.isNotEmpty) {
        try {
          final result = await _handleToolCall(name, arguments);
          print('工具调用结果name:${name};result: $result');

          // 添加工具调用结果到消息历史
          messages.add({
            'role': 'tool',
            'tool_call_id': toolCallId,
            'content': result,
          });
        } catch (e) {
          print('工具调用失败: $e');
          messages.add({
            'role': 'tool',
            'tool_call_id': toolCallId,
            'content': '工具调用失败，请稍后重试。',
          });
        }
      }
    }

    // 重新请求AI处理工具调用结果
    try {
      print('开始第二次API调用处理工具结果...');

      // 创建新的请求，不包含tools参数，避免再次触发工具调用
      final apiKey = await DeepSeekConfigService.getApiKey();
      final requestData = {
        'model': 'deepseek-chat',
        'messages': messages,
        'stream': true,
        // 不包含tools，让AI直接回复
        'tool_choice': 'none',
      };

      final response = await _dio.post(
        'https://api.deepseek.com/chat/completions',
        data: requestData,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      bool hasReceivedData = false;
      String finalResponse = '';

      _lastStreamSub = (response.data as ResponseBody).stream
          .map((bytes) => utf8.decode(bytes))
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.isEmpty || !line.startsWith('data: ')) return;

              final data = line.substring(6);
              if (data == '[DONE]') {
                print('第二次API调用完成，收到数据: $hasReceivedData');
                return;
              }

              try {
                final json = jsonDecode(data);
                final choices = json['choices'] as List?;
                if (choices == null || choices.isEmpty) return;

                final choice = choices.first;
                final delta = choice['delta'];

                // print("第二次API流数据: ${choices.first}");

                if (delta['content'] != null) {
                  print('第二次API流数据 delta: $delta');
                  hasReceivedData = true;
                  final content = _sanitizeText(delta['content'] as String);
                  if (content.isNotEmpty) {
                    // print('content: $content');
                    finalResponse += content;
                    print('finalResponse: $finalResponse');
                    print('controller.isClosed: ${controller.isClosed}');
                    if (!controller.isClosed) {
                      // 替换"正在分析数据..."为实际响应
                      final displayText = accumulated + '\n\n' + finalResponse;
                      print('controller.add(displayText): $displayText');
                      controller.add(displayText);
                      print(
                        '发送数据到前端: ${content.substring(0, content.length > 50 ? 50 : content.length)}...',
                      );
                    }
                  }
                }
              } catch (e) {
                print('解析第二次API响应失败: $e');
              }
            },
            onError: (e) {
              print('第二次API调用流错误: $e');
              if (!controller.isClosed) {
                controller.add(accumulated + '\n\n处理分析结果时出错，请稍后重试。');
                controller.close();
              }
            },
            onDone: () {
              print('第二次API调用流结束');
              if (!controller.isClosed) {
                if (finalResponse.isNotEmpty) {
                  // 最终内容推送到前端
                  final displayText = accumulated + '\n\n' + finalResponse;
                  controller.add(displayText);
                } else if (!hasReceivedData) {
                  controller.add(
                    accumulated + '\n\n根据分析结果，您的情绪状态处于一般水平，建议关注情绪变化。',
                  );
                }
                controller.close();
              }
            },
          );
    } catch (e, stackTrace) {
      print('重新请求AI失败: $e');
      print('堆栈跟踪: $stackTrace');
      if (!controller.isClosed) {
        controller.add(accumulated + '\n\n处理分析结果时出错，请稍后重试。');
        controller.close();
      }
    }
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
          final analysis = await _analyticsService.getMoodTrendAnalysis(
            dateRange,
          );
          return '心情趋势分析：平均心情指数${analysis.averageMoodIndex.toStringAsFixed(1)}，心情水平${analysis.moodLevel}，情绪波动性${analysis.moodVolatility.toStringAsFixed(2)}';

        case 'getUsageBehaviorAnalysis':
          final behavior = await _analyticsService.getUsageBehaviorAnalysis(
            dateRange,
          );
          return '使用行为分析：最活跃时段${behavior.mostActiveHour}点，平均使用时长信息，使用频率信息';

        case 'getContentAnalysisInsights':
          final insights = await _analyticsService.getContentAnalysisInsights(
            dateRange,
          );
          return '内容分析洞察：平均内容长度${insights.averageContentLength.toStringAsFixed(0)}字，内容质量${insights.contentLengthLevel}，总记录数${insights.totalRecords}条';

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
