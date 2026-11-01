/// 界面共用的中文书法字体回退链：优先楷体，其次各平台常见的中文字体。
const List<String> kKaiFontFallback = [
  'STKaiti',
  'Microsoft YaHei UI',
  'SimSun',
  'Noto Serif CJK SC',
  'Noto Sans CJK SC',
];

class AppConstants {
  AppConstants._();

  static const String appName = '中国象棋';
  static const String version = '0.5.1';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyDifficulty = 'difficulty';
  static const String prefKeyHumanSide = 'human_side';
  static const String prefKeyShowHints = 'show_hints';
  static const String prefKeyShowOpeningHints = 'show_opening_hints';
  static const String prefKeyBoardSkin = 'board_skin';
  static const String prefKeySound = 'sound_enabled';
  static const String prefKeyHaptics = 'haptics_enabled';
  static const String prefKeyTimeControl = 'time_control';
  static const String prefKeySolvedPuzzles = 'solved_puzzles';

  /// 单关最佳步数的存储键：`puzzle_best_<id>`。
  static String puzzleBestKey(String id) => 'puzzle_best_$id';

  /// 60 回合（120 个半步）无吃子判和。
  static const int drawNoCapturePlies = 120;
}
