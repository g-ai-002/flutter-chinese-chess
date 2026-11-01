import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../services/storage_service.dart';

/// 用户偏好：主题、难度、先后手、走法提示。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage);

  final StorageService _storage;

  bool get darkMode => _storage.darkMode;
  Future<void> setDarkMode(bool value) =>
      _update(() => _storage.setDarkMode(value));

  Difficulty get difficulty => _storage.difficulty;
  Future<void> setDifficulty(Difficulty value) =>
      _update(() => _storage.setDifficulty(value));

  int get humanSide => _storage.humanSide;
  Future<void> setHumanSide(int value) =>
      _update(() => _storage.setHumanSide(value));

  bool get showHints => _storage.showHints;
  Future<void> setShowHints(bool value) =>
      _update(() => _storage.setShowHints(value));

  bool get showOpeningHints => _storage.showOpeningHints;
  Future<void> setShowOpeningHints(bool value) =>
      _update(() => _storage.setShowOpeningHints(value));

  bool isPuzzleSolved(String id) => _storage.isPuzzleSolved(id);
  int? puzzleBestMoves(String id) => _storage.puzzleBestMoves(id);

  Future<void> recordPuzzleCleared(String id, int moves) =>
      _update(() => _storage.recordPuzzleCleared(id, moves));

  /// 写入偏好后统一通知界面，避免每个 setter 重复一遍。
  Future<void> _update(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }
}
