class MoodScoring {
  // 心情评分映射表
  static const Map<String, int> _moodScores = {
    '😍兴奋': 10,
    '😊开心': 9,
    '😌平静': 7,
    '🤔思考': 6,
    '😴疲惫': 5,
    '😰焦虑': 4,
    '😔难过': 3,
    '😤愤怒': 2,
  };

  /// 获取心情分数
  static int getMoodScore(String mood) {
    return _moodScores[mood] ?? 5; // 默认中性分数
  }

  /// 获取所有心情及其分数
  static Map<String, int> getAllMoodScores() {
    return Map.from(_moodScores);
  }

  /// 根据分数获取心情等级描述
  static String getMoodLevel(double score) {
    if (score >= 8.5) return '非常积极';
    if (score >= 7.0) return '积极';
    if (score >= 5.5) return '平和';
    if (score >= 4.0) return '一般';
    if (score >= 2.5) return '消极';
    return '非常消极';
  }

  /// 获取心情等级对应的颜色
  static String getMoodLevelColor(double score) {
    if (score >= 8.5) return '#4CAF50'; // 深绿
    if (score >= 7.0) return '#8BC34A'; // 浅绿
    if (score >= 5.5) return '#FFC107'; // 黄色
    if (score >= 4.0) return '#FF9800'; // 橙色
    if (score >= 2.5) return '#FF5722'; // 深橙
    return '#F44336'; // 红色
  }

  /// 计算心情指数列表的平均值
  static double calculateAverageScore(List<int> scores) {
    if (scores.isEmpty) return 5.0; // 默认中性分数
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}