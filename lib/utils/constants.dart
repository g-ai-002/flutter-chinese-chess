class AppConstants {
  AppConstants._();

  static const String appName = '中国象棋';
  static const String version = '0.1.0';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyDifficulty = 'difficulty';
  static const String prefKeyHumanSide = 'human_side';
  static const String prefKeyShowHints = 'show_hints';

  /// 60 回合（120 个半步）无吃子判和。
  static const int drawNoCapturePlies = 120;
}
