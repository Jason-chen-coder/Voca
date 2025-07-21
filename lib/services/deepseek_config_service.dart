import 'package:dart_openai/dart_openai.dart';
import '../database/database_helper.dart';

class DeepSeekConfigService {
  static const String _baseUrl = 'https://api.deepseek.com';
  static bool _isInitialized = false;
  
  /// 保存API密钥到SQLite
  static Future<void> saveApiKey(String apiKey) async {
    try {
      final db = await DatabaseHelper().database;
      
      // 先删除旧的密钥
      await db.delete('config', where: 'key = ?', whereArgs: ['deepseek_api_key']);
      
      // 插入新的密钥
      await db.insert('config', {
        'key': 'deepseek_api_key',
        'value': apiKey,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      
      _isInitialized = false; // 重置初始化状态
    } catch (e) {
      throw Exception('存储失败：$e');
    }
  }
  
  /// 从SQLite获取API密钥
  static Future<String?> getApiKey() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'config',
        where: 'key = ?',
        whereArgs: ['deepseek_api_key'],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        return result.first['value'] as String?;
      }
      return null;
    } catch (e) {
      print('读取API密钥失败: $e');
      return null;
    }
  }
  
  /// 删除API密钥
  static Future<void> clearApiKey() async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('config', where: 'key = ?', whereArgs: ['deepseek_api_key']);
      _isInitialized = false;
    } catch (e) {
      print('删除API密钥失败: $e');
    }
  }
  
  /// 检查是否已配置API密钥
  static Future<bool> hasApiKey() async {
    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }
  
  /// 初始化OpenAI客户端用于DeepSeek API
  static Future<bool> initializeClient() async {
    if (_isInitialized) return true;
    
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) return false;
    
    OpenAI.apiKey = apiKey;
    OpenAI.baseUrl = _baseUrl;
    _isInitialized = true;
    
    return true;
  }
  
  /// 验证API密钥
  static Future<bool> validateApiKey(String apiKey) async {
    try {
      // 临时设置API密钥和基础URL进行验证
      final originalApiKey = apiKey;
      final originalBaseUrl = OpenAI.baseUrl;
      
      OpenAI.apiKey = apiKey;
      OpenAI.baseUrl = _baseUrl;
      
      // 发送一个简单的测试请求
      final response = await OpenAI.instance.chat.create(
        model: "deepseek-chat",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text('Hello')
            ],
          ),
        ],
      );
      
      // 恢复原始设置
      if (originalApiKey != null) OpenAI.apiKey = originalApiKey;
      if (originalBaseUrl != null) OpenAI.baseUrl = originalBaseUrl;
      
      return response.choices.isNotEmpty;
    } catch (e) {
      print('API密钥验证失败: $e');
      return false;
    }
  }

  /// 创建流式聊天完成请求
  static Stream<OpenAIStreamChatCompletionModel>? createChatCompletionStream({
    required String model,
    required List<OpenAIChatCompletionChoiceMessageModel> messages,
    int? maxTokens,
    double? temperature,
    List<OpenAIToolModel>? tools,
    String? toolChoice,
  }) async* {
    try {
      print('DeepSeek: 开始初始化客户端...');
      final initialized = await initializeClient();
      if (!initialized) {
        print('DeepSeek客户端初始化失败');
        return;
      }

      print('DeepSeek: 客户端初始化成功，创建流...');
      final stream = OpenAI.instance.chat.createStream(
        model: model,
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
        tools: tools,
        toolChoice: toolChoice,
      );

      print('DeepSeek: 开始监听流数据...');
      await for (final chunk in stream) {
        print('DeepSeek: 收到流数据chunk');
        yield chunk;
      }
      print('DeepSeek: 流数据处理完成');
    } catch (e) {
      print('创建流式聊天完成请求失败: $e');
      rethrow; // 重新抛出异常让上层处理
    }
  }

}
