import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_models.dart';
import '../utils/constants.dart';

/// 轻量偏好存储：写入失败时静默忽略，不影响对局主流程。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final service = StorageService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  /// 仅供测试：清空单例，配合 SharedPreferences 的 mock 数据使用。
  static void resetForTests() => _instance = null;

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) throw StateError('StorageService 尚未初始化');
    return prefs;
  }

  Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) action,
  ) async {
    try {
      await action(_p);
    } catch (_) {}
  }

  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;
  Future<void> setDarkMode(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyDarkMode, value));

  bool get showHints => _p.getBool(AppConstants.prefKeyShowHints) ?? true;
  Future<void> setShowHints(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyShowHints, value));

  /// 棋盘皮肤 id，未设置或未知值由 `boardSkinOf` 回退到默认皮肤。
  String? get boardSkinId => _p.getString(AppConstants.prefKeyBoardSkin);
  Future<void> setBoardSkinId(String value) =>
      _write((p) => p.setString(AppConstants.prefKeyBoardSkin, value));

  bool get soundEnabled => _p.getBool(AppConstants.prefKeySound) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeySound, value));

  bool get hapticsEnabled => _p.getBool(AppConstants.prefKeyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyHaptics, value));

  bool get showOpeningHints =>
      _p.getBool(AppConstants.prefKeyShowOpeningHints) ?? true;
  Future<void> setShowOpeningHints(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyShowOpeningHints, value));

  Difficulty get difficulty {
    final name = _p.getString(AppConstants.prefKeyDifficulty);
    return Difficulty.values.firstWhere(
      (item) => item.name == name,
      orElse: () => Difficulty.normal,
    );
  }

  Future<void> setDifficulty(Difficulty value) =>
      _write((p) => p.setString(AppConstants.prefKeyDifficulty, value.name));

  /// 人类执子方：0 红（先行），1 黑（后行）。
  int get humanSide => _p.getInt(AppConstants.prefKeyHumanSide) ?? 0;
  Future<void> setHumanSide(int value) =>
      _write((p) => p.setInt(AppConstants.prefKeyHumanSide, value));

  bool isPuzzleSolved(String id) =>
      (_p.getStringList(AppConstants.prefKeySolvedPuzzles) ?? const [])
          .contains(id);

  /// 单关最佳步数，未通关时为 null。
  int? puzzleBestMoves(String id) => _p.getInt(AppConstants.puzzleBestKey(id));

  Future<void> recordPuzzleCleared(String id, int moves) => _write((p) async {
    final solved = (p.getStringList(AppConstants.prefKeySolvedPuzzles) ?? [])
        .toList();
    if (!solved.contains(id)) {
      solved.add(id);
      await p.setStringList(AppConstants.prefKeySolvedPuzzles, solved);
    }
    final best = p.getInt(AppConstants.puzzleBestKey(id));
    if (best == null || moves < best) {
      await p.setInt(AppConstants.puzzleBestKey(id), moves);
    }
    return true;
  });
}
