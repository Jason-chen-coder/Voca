import 'package:flutter/material.dart';
import '../services/deepseek_config_service.dart';

class DeepSeekSettingsPage extends StatefulWidget {
  const DeepSeekSettingsPage({super.key});

  @override
  State<DeepSeekSettingsPage> createState() => _DeepSeekSettingsPageState();
}

class _DeepSeekSettingsPageState extends State<DeepSeekSettingsPage> {
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _isValidating = false;
  bool _hasApiKey = false;
  String? _maskedApiKey;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    final hasKey = await DeepSeekConfigService.hasApiKey();
    if (hasKey) {
      final apiKey = await DeepSeekConfigService.getApiKey();
      _maskedApiKey = _maskApiKey(apiKey!);
    }
    setState(() {
      _hasApiKey = hasKey;
    });
  }

  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return apiKey;
    return '${apiKey.substring(0, 4)}${'*' * (apiKey.length - 8)}${apiKey.substring(apiKey.length - 4)}';
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnackBar('请输入API密钥', Colors.orange);
      return;
    }

    setState(() => _isValidating = true);

    try {
      // 验证API密钥
      final isValid = await DeepSeekConfigService.validateApiKey(apiKey);
      if (!isValid) {
        _showSnackBar('API密钥无效，请检查后重试', Colors.red);
        return;
      }

      // 保存API密钥
      await DeepSeekConfigService.saveApiKey(apiKey);
      _showSnackBar('API密钥保存成功！', Colors.green);
      
      // 更新UI状态
      setState(() {
        _hasApiKey = true;
        _maskedApiKey = _maskApiKey(apiKey);
      });
      _apiKeyController.clear();

    } catch (e,stack) {
      print("保存失败error: $e,stack:${stack}");
      _showSnackBar('保存失败: $e', Colors.red);
    } finally {
      setState(() => _isValidating = false);
    }
  }

  Future<void> _clearApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除API密钥'),
        content: const Text('确定要删除已保存的API密钥吗？'),
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
      await DeepSeekConfigService.clearApiKey();
      setState(() {
        _hasApiKey = false;
        _maskedApiKey = null;
      });
      _showSnackBar('API密钥已删除', Colors.grey);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F8F2),
      appBar: AppBar(
        title: const Text('DeepSeek API 设置'),
        backgroundColor: const Color(0xFF31DA9F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasApiKey ? Icons.check_circle : Icons.warning,
                          color: _hasApiKey ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasApiKey ? 'API密钥已配置' : 'API密钥未配置',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_hasApiKey) ...[
                      const SizedBox(height: 8),
                      Text(
                        '当前密钥: $_maskedApiKey',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'API密钥配置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请输入您的DeepSeek API密钥。您可以在DeepSeek官网获取API密钥。',
              style: TextStyle(color: Colors.grey),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API密钥',
                hintText: '请输入DeepSeek API密钥',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: _isValidating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              obscureText: true,
              maxLines: 1,
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : _saveApiKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF31DA9F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isValidating
                        ? const Text('验证中...')
                        : const Text('保存并验证'),
                  ),
                ),
                if (_hasApiKey) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _clearApiKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('删除'),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 24),
            
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          '使用说明',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• API密钥将安全存储在设备本地\n'
                      '• 配置成功后即可使用AI智能分析功能\n'
                      '• 如需更换密钥，请先删除现有密钥再重新配置',
                      style: TextStyle(fontSize: 14),
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
}