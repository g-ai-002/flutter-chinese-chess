import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../services/storage_service.dart';

/// 用户偏好：主题、难度、先后手、走法提示。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage);

  final StorageService _storage;

  bool get darkMode => _storage.darkMode;
  Future<void> setDarkMode(bool value) async {
    await _storage.setDarkMode(value);
    notifyListeners();
  }

  Difficulty get difficulty => _storage.difficulty;
  Future<void> setDifficulty(Difficulty value) async {
    await _storage.setDifficulty(value);
    notifyListeners();
  }

  int get humanSide => _storage.humanSide;
  Future<void> setHumanSide(int value) async {
    await _storage.setHumanSide(value);
    notifyListeners();
  }

  bool get showHints => _storage.showHints;
  Future<void> setShowHints(bool value) async {
    await _storage.setShowHints(value);
    notifyListeners();
  }

  String get humanSideLabel => humanSide == 0 ? '执红先行' : '执黑后行';
}
