import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_statistics.dart';
import '../game/logic_rate.dart';
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

  bool get musicEnabled => _p.getBool(AppConstants.prefKeyMusic) ?? true;
  Future<void> setMusicEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyMusic, value));

  bool get hapticsEnabled => _p.getBool(AppConstants.prefKeyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyHaptics, value));

  /// 棋钟方案，未设置或未知值回退到不限时。
  TimeControl get timeControl =>
      TimeControl.byName(_p.getString(AppConstants.prefKeyTimeControl));
  Future<void> setTimeControl(TimeControl value) =>
      _write((p) => p.setString(AppConstants.prefKeyTimeControl, value.name));

  /// 棋盘逻辑更新速率，未设置或未知值回退到 60Hz。
  LogicRate get logicRate =>
      LogicRate.byName(_p.getString(AppConstants.prefKeyLogicRate));
  Future<void> setLogicRate(LogicRate value) =>
      _write((p) => p.setString(AppConstants.prefKeyLogicRate, value.name));

  /// AI 难度，未设置或未知值回退到默认难度（高手）。
  Difficulty get difficulty =>
      Difficulty.byName(_p.getString(AppConstants.prefKeyDifficulty));

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

  /// 人机对战累计战绩，未打过时为全零。
  GameStatistics get gameStatistics => GameStatistics(
    wins: _p.getInt(AppConstants.prefKeyStatsWins) ?? 0,
    losses: _p.getInt(AppConstants.prefKeyStatsLosses) ?? 0,
    draws: _p.getInt(AppConstants.prefKeyStatsDraws) ?? 0,
    streak: _p.getInt(AppConstants.prefKeyStatsStreak) ?? 0,
    bestStreak: _p.getInt(AppConstants.prefKeyStatsBestStreak) ?? 0,
  );

  /// 记一局人机对战：胜为 true、和为 null、负为 false。
  Future<void> recordHumanResult(bool? won) => _write((p) async {
    final next = gameStatistics.record(won);
    await p.setInt(AppConstants.prefKeyStatsWins, next.wins);
    await p.setInt(AppConstants.prefKeyStatsLosses, next.losses);
    await p.setInt(AppConstants.prefKeyStatsDraws, next.draws);
    await p.setInt(AppConstants.prefKeyStatsStreak, next.streak);
    await p.setInt(AppConstants.prefKeyStatsBestStreak, next.bestStreak);
    return true;
  });
}
