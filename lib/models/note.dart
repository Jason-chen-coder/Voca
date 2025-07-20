class Note {
  final int? id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? mood;

  Note({
    this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'mood': mood,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      mood: map['mood'] as String?,
    );
  }
}
