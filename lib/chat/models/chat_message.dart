class ChatMessage {
  final int? id;
  final String content;
  final bool isUser;
  final DateTime createdAt;
  final String? messageType; // 'text', 'analysis', 'suggestion'
  final Map<String, dynamic>? metadata; // 存储额外信息

  ChatMessage({
    this.id,
    required this.content,
    required this.isUser,
    required this.createdAt,
    this.messageType = 'text',
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'message_type': messageType,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      content: map['content'],
      isUser: map['is_user'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      messageType: map['message_type'] ?? 'text',
      metadata: map['metadata'] != null ? _decodeMetadata(map['metadata']) : null,
    );
  }

  static String _encodeMetadata(Map<String, dynamic> metadata) {
    // 简单的JSON编码，实际项目中可以使用dart:convert
    return metadata.toString();
  }

  static Map<String, dynamic>? _decodeMetadata(String? metadataStr) {
    // 简单实现，实际项目中需要proper JSON解析
    return null;
  }
}